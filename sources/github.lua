local curl = require("cURL.safe")
local json = require("cjson.safe")
local version = dofile("version.lua")

local token = os.getenv("GITHUB_TOKEN")

local function fetch_json(repo, request)
	local page_end = 0
	local header_queue = {}
	local queue = {}
	local url = string.format("https://api.github.com/repos/%s/%s", repo, request)
	local headers = {
		"Accept: application/json",
		"Authorization: token " .. token,
		"User-Agent: pkg-version-tools",
	}
	local request = curl.easy()
		:setopt_customrequest("GET")
		:setopt_url(url)
		:setopt_httpheader(headers)
		:setopt_writefunction(function(buffer)
			table.insert(queue, buffer)
		end)
		:setopt_headerfunction(function(buffer)
			local match = buffer:match('page=[0-9]*>; rel="last"')
			if match ~= nil then
				page_end = tonumber(match:sub(6):match("[0-9]*"))
			end
		end)
	request:perform()
	request:close()
	local output = table.concat(queue, "")
	local json, err = json.decode(output)
	return json, err, page_end
end

local function best_in_page(json, best_ver)
	for i = 1, #json do
		local v = json[i].name
		if not v:match("^untagged*") and version.valid(v) then
			v = version.sanitize(v)
			if version.compare(best_ver, v) < 0 then
				best_ver = v
			end
		end
	end
	return best_ver
end

local function get_version_tag(repo, best_ver, page)
	local json, err
	if page == nil then
		json, err, page = fetch_json(repo, "tags?page=1")
		page = page + 1
	else
		json, err = fetch_json(repo, string.format("tags?page=%d", page))
	end
	if json == nil then
		return nil
	end
	if json.message ~= nil then
		return nil
	end
	best_ver = best_in_page(json, best_ver == nil and "0" or best_ver)
	if page > 3 then
		return get_version_tag(repo, best_ver, page - 1)
	end
	return best_ver ~= "0" and best_ver or nil
end

local function get_version_release(repo)
	local json = fetch_json(repo, "releases/latest")
	if json == nil then return nil end
	if json.tag_name ~= nil and version.valid(json.tag_name) then
		return version.sanitize(json.tag_name)
	end
	return nil
end

function get_version(repo)
	local v
	v = get_version_release(repo)
	if v ~= nil then return v end
	v = get_version_tag(repo)
	if v ~= nil then return v end
	return nil
end

--print(get_version(arg[1]))

return {
	get_version = get_version
}
