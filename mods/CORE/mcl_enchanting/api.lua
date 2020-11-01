function mcl_enchanting.get_enchantments(itemstack)
	return minetest.deserialize(itemstack:get_meta():get_string("mcl_enchanting:enchantments")) or {}
end

function mcl_enchanting.set_enchantments(itemstack, enchantments)
	itemstack:get_meta():set_string("mcl_enchanting:enchantments", minetest.serialize(enchantments))
	local itemdef = itemstack:get_definition()
	for enchantment, level in pairs(enchantments) do
		local enchantment_def = mcl_enchanting.enchantments[enchantment]
		if enchantment_def.on_enchant then
			enchantment_def.on_enchant(itemstack, level, itemdef)
		end
	end
	tt.reload_itemstack_description(itemstack)
end

function mcl_enchanting.get_enchantment(itemstack, enchantment)
	return mcl_enchanting.get_enchantments(itemstack)[enchantment] or 0
end

function mcl_enchanting.has_enchantment(itemstack, enchantment)
	return mcl_enchanting.get_enchantment(itemstack, enchantment) > 0
end

function mcl_enchanting.get_enchantment_description(enchantment, level)
	local enchantment_def = mcl_enchanting.enchantments[enchantment]
	return enchantment_def.name .. (enchantment_def.max_level == 1 and "" or " " .. mcl_enchanting.roman_numerals.toRoman(level))
end

function mcl_enchanting.get_colorized_enchantment_description(enchantment, level)
	return minetest.colorize(mcl_enchanting.enchantments[enchantment].curse and "#FC5454" or "#A8A8A8", mcl_enchanting.get_enchantment_description(enchantment, level))
end

function mcl_enchanting.get_enchanted_itemstring(itemname)
	local def = minetest.registered_items[itemname]
	return def and def._mcl_enchanting_enchanted_tool
end

function mcl_enchanting.is_enchanted_def(itemname)
	return minetest.get_item_group(itemname, "enchanted") > 0
end

function mcl_enchanting.is_enchanted(itemstack)
	return mcl_enchanting.is_enchanted_def(itemstack:get_name())
end

function mcl_enchanting.item_supports_enchantment(itemname, enchantment, early)
	if not early and not mcl_enchanting.get_enchanted_itemstring(itemname) then
		return false
	end
	local enchantment_def = mcl_enchanting.enchantments[enchantment]
	local itemdef = minetest.registered_items[itemname]
	if itemdef.type ~= "tool" and enchantment_def.requires_tool then
		return false
	end
	for disallow in pairs(enchantment_def.disallow) do
		if minetest.get_item_group(itemname, disallow) > 0 then
			return false
		end
	end
	for group in pairs(enchantment_def.all) do
		if minetest.get_item_group(itemname, group) > 0 then
			return true
		end
	end
	return false
end

function mcl_enchanting.can_enchant(itemstack, enchantment, level)
	local enchantment_def = mcl_enchanting.enchantments[enchantment]
	if not enchantment_def then
		return false, "enchantment invalid"
	end
	if itemstack:get_name() == "" then
		return false, "item missing"
	end
	if not mcl_enchanting.item_supports_enchantment(itemstack:get_name(), enchantment) then
		return false, "item not supported"
	end
	if not level then
		return false, "level invalid"
	end
	if level > enchantment_def.max_level then
		return false, "level too high", enchantment_def.max_level
	elseif  level < 1 then
		return false, "level too small", 1
	end
	local item_enchantments = mcl_enchanting.get_enchantments(itemstack)
	local enchantment_level = item_enchantments[enchantment]
	if enchantment_level then
		return false, "incompatible", mcl_enchanting.get_enchantment_description(enchantment, enchantment_level)
	end
	for incompatible in pairs(enchantment_def.incompatible) do
		local incompatible_level = item_enchantments[incompatible]
		if incompatible_level then
			return false, "incompatible", mcl_enchanting.get_enchantment_description(incompatible, incompatible_level)
		end
	end
	return true
end

function mcl_enchanting.enchant(itemstack, enchantment, level)
	itemstack:set_name(mcl_enchanting.get_enchanted_itemstring(itemstack:get_name()))
	local enchantments = mcl_enchanting.get_enchantments(itemstack)
	enchantments[enchantment] = level
	mcl_enchanting.set_enchantments(itemstack, enchantments)
	return itemstack
end

function mcl_enchanting.combine(itemstack, combine_with)
	local itemname = itemstack:get_name()
	local enchanted_itemname = mcl_enchanting.get_enchanted_itemstring(itemname)
	if enchanted_itemname ~= mcl_enchanting.get_enchanted_itemstring(combine_with:get_name()) then
		return false
	end
	local enchantments = mcl_enchanting.get_enchantments(itemstack)
	for enchantment, combine_level in pairs(mcl_enchanting.get_enchantments(combine_with)) do
		local enchantment_def = mcl_enchanting.enchantments[enchantment]
		local enchantment_level = enchantments[combine_enchantment]
		if enchantment_level then
			if enchantment_level == combine_level then
				enchantment_level = math.min(enchantment_level + 1, enchantment_def.max_level)
			end
		elseif mcl_enchanting.item_supports_enchantment(itemname, enchantment) then
			local supported = true
			for incompatible in pairs(enchantment_def.incompatible) do
				if enchantments[incompatible] then
					supported = false
					break
				end
			end
			if supported then
				enchantment_level = combine_level
			end
		end
		enchantments[enchantment] = enchantment_level
	end
	local any_enchantment = false
	for enchantment, enchantment_level in pairs(enchantments) do
		if enchantment_level > 0 then
			any_enchantment = true
			break
		end
	end
	if any_enchantment then
		itemstack:set_name(enchanted_itemname)
	end
	mcl_enchanting.set_enchantments(itemstack, enchantments)
	return true
end

function mcl_enchanting.initialize()
	local tool_list = {}
	local item_list = {}
	for enchantment, enchantment_def in pairs(mcl_enchanting.enchantments) do
		local all_item_groups = {}
		for primary in pairs(enchantment_def.primary) do
			all_item_groups[primary] = true
			mcl_enchanting.all_item_groups[primary] = true
		end
		for secondary in pairs(enchantment_def.secondary) do
			all_item_groups[secondary] = true
			mcl_enchanting.all_item_groups[secondary] = true
		end
		enchantment_def.all = all_item_groups
		mcl_enchanting.total_weight = mcl_enchanting.total_weight + enchantment_def.weight
	end
	for itemname, itemdef in pairs(minetest.registered_items) do
		if itemdef.groups.enchanted then
			break
		end
		local quick_test = false
		for group, groupv in pairs(itemdef.groups) do
			if groupv > 0 and mcl_enchanting.all_item_groups[group] then
				quick_test = true
				break
			end
		end
		if quick_test then
			if mcl_enchanting.debug then
				print(itemname)
			end
			local expensive_test = false
			for enchantment in pairs(mcl_enchanting.enchantments) do
				if mcl_enchanting.item_supports_enchantment(itemname, enchantment, true) then
					expensive_test = true
					if mcl_enchanting.debug then 
						print("\tSupports " .. enchantment)
					else
						break
					end
				end
			end
			if expensive_test then
				local new_name = itemname .. "_enchanted"
				minetest.override_item(itemname, {_mcl_enchanting_enchanted_tool = new_name})
				local new_def = table.copy(itemdef)
				new_def.inventory_image = itemdef.inventory_image .. "^[colorize:purple:50"
				new_def.groups.not_in_creative_inventory = 1
				new_def.groups.enchanted = 1
				new_def.texture = itemdef.texture or itemname:gsub("%:", "_")
				new_def._mcl_enchanting_enchanted_tool = new_name
				local register_list = item_list
				if itemdef.type == "tool" then
					register_list = tool_list
				end
				register_list[":" .. new_name] = new_def
			end
		end
	end
	for new_name, new_def in pairs(item_list) do
		minetest.register_craftitem(new_name, new_def)
	end
	for new_name, new_def in pairs(tool_list) do
		minetest.register_tool(new_name, new_def)
	end
end

--[[
minetest.register_on_mods_loaded(function()
	for toolname, tooldef in pairs(minetest.registered_tools) do
		for _, material in pairs(tooldef.materials) do
			local full_name = toolname .. ((material == "") and "" or "_" .. material)
			local old_def = minetest.registered_tools[full_name]
			if not old_def then break end
			mcl_enchanting.all_tools[full_name] = toolname
			for _, enchantment in pairs(tooldef.enchantments) do
				local enchantment_def = mcl_enchanting.enchantments[enchantment]
				for lvl = 1, enchantment_def.max_level do
					local new_def = table.copy(old_def)
					new_def.description = minetest.colorize("#54FCFC", old_def.description) .. "\n" .. mcl_enchanting.get_enchantment_description(enchantment, lvl)
					new_def.inventory_image = old_def.inventory_image .. "^[colorize:violet:50"
					new_def.groups.not_in_creative_inventory = 1
					new_def.texture = old_def.texture or full_name:gsub("%:", "_")
					new_def._original_tool = full_name
					enchantment_def.create_itemdef(new_def, lvl)
					minetest.register_tool(":" .. full_name .. "_enchanted_" .. enchantment .. "_" .. lvl, new_def)
				end
			end
		end
	end
end)
--]]