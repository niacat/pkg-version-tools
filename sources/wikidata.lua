local curl = require("cURL.safe")
local json = require("cjson.safe")
local version = dofile("version.lua")

local function fetch_json(entity)
	local queue = {}
	local url = string.format("https://www.wikidata.org/w/api.php?action=wbgetclaims&entity=%s&property=P348&format=json", entity)
	local request = curl.easy()
		:setopt_customrequest("GET")
		:setopt_url(url)
		:setopt_httpheader({"Accept: application/json"})
		:setopt_writefunction(function(buffer)
			table.insert(queue, buffer)
		end)
	request:perform()
	request:close()
	return json.decode(table.concat(queue, ""))
end

local function check_valid_id(id)
	local invalid_ids = {
		"Q3295609",		-- beta
		"Q2122918",		-- alpha
		"Q1072356",		-- RC
		"Q51930650",	-- pre-release
		"Q21683863",	-- obsolete version
		"Q21727724",	-- unstable version
		"Q5209391",		-- daily build
	}
	for i = 1, #invalid_ids do
		if id == invalid_ids[i] then return false end
	end
	return true
end

local function claim_valid(claim)
	if claim.qualifiers ~= nil then
		local v_type = claim.qualifiers.P548
		if v_type ~= nil and not check_valid_id(v_type[1].datavalue.value.id) then
			return nil
		end
	end
	return version.valid(claim.mainsnak.datavalue.value)
end

local function get_preferred_claim(claimset)
	local best_ver = nil
	for i = 1, #claimset do
		if claim_valid(claimset[i]) then
			local ver = version.sanitize(claimset[i].mainsnak.datavalue.value)
			if best_ver == nil or version.compare(best_ver, ver) < 0 then
				best_ver = ver
			end
		end
	end
	return best_ver
end

function get_version(entity)
	local json, err = fetch_json(entity)
	if json == nil then
		print(err)
		return nil
	end
	if json.claims.P348 == nil then
		return nil
	end
	local pref = get_preferred_claim(json.claims.P348);
	if pref == nil then
		-- return the last valid value if none is preferred
		for i = #json.claims.P348, 1, -1 do
			local claim = json.claims.P348[i]
			if (claim_valid(claim)) then
				return version.sanitize(claim.mainsnak.datavalue.value)
			end
		end
	end
	return pref
end

--print(get_version(arg[1]))

return {
	get_version = get_version
}
