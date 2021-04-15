local math_pi     = math.pi
local math_sin    = math.sin
local math_cos    = math.cos

-- set defined animation
local set_animation = function(self, anim, fixed_frame)
	if not self.animation or not anim then
		return
	end
	if self.state == "die" and anim ~= "die" and anim ~= "stand" then
		return
	end

	self.animation.current = self.animation.current or ""

	if (anim == self.animation.current
	or not self.animation[anim .. "_start"]
	or not self.animation[anim .. "_end"]) and self.state ~= "die" then
		return
	end

	self.animation.current = anim

	local a_start = self.animation[anim .. "_start"]
	local a_end
	if fixed_frame then
		a_end = a_start
	else
		a_end = self.animation[anim .. "_end"]
	end

	self.object:set_animation({
		x = a_start,
		y = a_end},
		self.animation[anim .. "_speed"] or self.animation.speed_normal or 15,
		0, self.animation[anim .. "_loop"] ~= false)
end


-- above function exported for mount.lua
function mobs:set_animation(self, anim)
	set_animation(self, anim)
end




mobs.death_effect = function(pos, yaw, collisionbox, rotate)
	local min, max
	if collisionbox then
		min = {x=collisionbox[1], y=collisionbox[2], z=collisionbox[3]}
		max = {x=collisionbox[4], y=collisionbox[5], z=collisionbox[6]}
	else
		min = { x = -0.5, y = 0, z = -0.5 }
		max = { x = 0.5, y = 0.5, z = 0.5 }
	end
	if rotate then
		min = vector.rotate(min, {x=0, y=yaw, z=math_pi/2})
		max = vector.rotate(max, {x=0, y=yaw, z=math_pi/2})
		min, max = vector.sort(min, max)
		min = vector.multiply(min, 0.5)
		max = vector.multiply(max, 0.5)
	end

	minetest_add_particlespawner({
		amount = 50,
		time = 0.001,
		minpos = vector.add(pos, min),
		maxpos = vector.add(pos, max),
		minvel = vector.new(-5,-5,-5),
		maxvel = vector.new(5,5,5),
		minexptime = 1.1,
		maxexptime = 1.5,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		vertical = false,
		texture = "mcl_particles_mob_death.png^[colorize:#000000:255",
	})

	minetest_sound_play("mcl_mobs_mob_poof", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = 8,
	}, true)
end


--this allows auto facedir rotation while making it so mobs
--don't look like wet noodles flopping around
mobs.movement_rotation_lock = function(self)
	
	local current_engine_yaw = self.object:get_yaw()
	local current_lua_yaw = self.yaw

	if current_engine_yaw > math.pi * 2 then
		current_engine_yaw = current_engine_yaw - (math.pi * 2)
	end

	if math.abs(current_engine_yaw - current_lua_yaw) <= 0.05 and self.object:get_properties().automatic_face_movement_dir then
		self.object:set_properties{automatic_face_movement_dir = false}
	elseif math.abs(current_engine_yaw - current_lua_yaw) > 0.05 and self.object:get_properties().automatic_face_movement_dir == false then
		self.object:set_properties{automatic_face_movement_dir = self.rotate}
	end
end