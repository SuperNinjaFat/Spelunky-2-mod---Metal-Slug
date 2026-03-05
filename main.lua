local celib = require("custom_entities")

meta = {
	name = "Metal Slug Weapons",
	version = "1.0",
	author = "Super Ninja Fat, The Greeni Porcini",
	description = "Metal Slug weapons! In Spelunky 2!",
}

local machine_gun_texture_id
do
	local machine_gun_texture_def = TextureDefinition.new()
	machine_gun_texture_def.width = 768
	machine_gun_texture_def.height = 128
	machine_gun_texture_def.tile_width = 128
	machine_gun_texture_def.tile_height = 128
	machine_gun_texture_def.texture_path = "HEAVY_MACHINE_GUN.png"
	machine_gun_texture_id = define_texture(machine_gun_texture_def)
end

-- TODO:
--[[
    - Video reference: https://www.youtube.com/watch?v=UGE8Eiy5yp0
    - [x] Define the custom item as a gun, but define the fire function as nothing
    - [x] Add our own update function to
        - check whether the overlay is a player and if the whip button is held down during pre-update state to fire.
        - update shot delay timer
        \*Will need to be careful to only fire during times when a player is allowed to fire
    - [ ] Have hiredhands have a chance of spawning with them (instead of a skull?)
]]

-- Play sound
local function play_vanilla_sound(vanilla_sound)
	local sound = get_sound(vanilla_sound)
	if sound then
		sound:play()
	end
end

---@class HeavyMachineGunData
---@field shot_timer integer

---@class HeavyMachineGun : Gun
----@field user_data HeavyMachineGunData

--Spawn
local function spawn_bullet(x, y, l, dir, owner_uid)
	local offset = 0.5
	local vx = 0
	local max_y_spread <const> = 0.02
	local vy = (prng:random_float(PRNG_CLASS.PARTICLES) * max_y_spread * 2) - max_y_spread
	local bullet = get_entity(spawn_entity(ENT_TYPE.ITEM_BULLET, x + dir * offset, y - 0.1, l, vx + dir / 2, vy))--[[@as Bullet]]
	--Makes shopkeepers mad at your projectile
	bullet.last_owner_uid = owner_uid

	if dir == -1 then
		-- facing left
		bullet.flags = set_flag(bullet.flags, ENT_FLAG.FACING_LEFT)
	else
		-- facing right
		bullet.flags = clr_flag(bullet.flags, ENT_FLAG.FACING_LEFT)
	end
end

---@param self HeavyMachineGun
local function shoot_bullet(self)
	-- Play sound
	-- play_vanilla_sound(VANILLA_SOUND.ITEMS_SHOTGUN_FIRE)
	play_vanilla_sound(VANILLA_SOUND.CRITTERS_DRONE_CRASH)

	local dir = test_flag(self.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
	local x, y, l = get_position(self.overlay.uid)
	spawn_bullet(x, y, l, dir, self.overlay.uid)

	local x_shot_offset <const> = 1.25

	local shotgun_blast = get_entity(spawn_entity(ENT_TYPE.FX_SHOTGUNBLAST, x + dir * x_shot_offset, y - 0.1, l, 0, 0))--[[@as FxShotgunBlast]]
	-- shotgun_blast.flags = (shotgun_blast.flags & ~ENT_FLAG.FACING_LEFT) | (self.flags & ENT_FLAG.FACING_LEFT)
	shotgun_blast.flags = dir == -1 and set_flag(shotgun_blast.flags, ENT_FLAG.FACING_LEFT)
		or clr_flag(shotgun_blast.flags, ENT_FLAG.FACING_LEFT)
	local shot_size <const> = 0.75
	shotgun_blast.width = shot_size
	shotgun_blast.height = shot_size

	local smoke_emitter = generate_world_particles(PARTICLEEMITTER.SHOTGUNBLAST_SMOKE, self.uid)
	smoke_emitter.offset_x = dir * 1
	local sparks_emitter = generate_world_particles(PARTICLEEMITTER.SHOTGUNBLAST_SPARKS, self.uid)
	sparks_emitter.offset_x = dir * 1
end

local SHOT_TIMEOUT <const> = 3

---@param ent HeavyMachineGun
---@param c_data HeavyMachineGunData
local function machinegun_update(ent, c_data)
	--only fire when the player is holding it in the usual states they are allowed to fire weapons in
	if
		ent.overlay
		and ent.overlay.type.search_flags == MASK.PLAYER
		and (
			ent.overlay.state == CHAR_STATE.STANDING
			or ent.overlay.state == CHAR_STATE.SITTING
			or ent.overlay.state == CHAR_STATE.CLIMBING
			or ent.overlay.state == CHAR_STATE.FALLING
			or ent.overlay.state == CHAR_STATE.FLAILING
			or ent.overlay.state == CHAR_STATE.JUMPING
		)
	then
		-- In hand
		local input = state.player_inputs.player_slots[ent.overlay.inventory.player_slot].buttons_gameplay
		if input & BUTTON.WHIP == BUTTON.WHIP and c_data.shot_timer == 0 then
			shoot_bullet(ent)
			c_data.shot_timer = SHOT_TIMEOUT
		end
	end

	if c_data.shot_timer > 0 then
		c_data.shot_timer = c_data.shot_timer - 1
	end
end

---@param ent HeavyMachineGun
---@param c_data HeavyMachineGunData
---@return table
local function machinegun_set(ent, c_data)
	---@type HeavyMachineGunData
	local custom_data = {
		shot_timer = 0,
	}
	ent:set_texture(machine_gun_texture_id)
	ent.animation_frame = 0
	add_custom_name(ent.uid, "Heavy Machinegun")
	celib.set_price(ent, 7500, 500)
	return custom_data
end

local machinegun_id = celib.new_custom_gun(
	machinegun_set,
	machinegun_update,
	function() end,
	20,
	0.18,
	0.015,
	ENT_TYPE.ITEM_FREEZERAY
)

celib.add_custom_shop_chance(machinegun_id, celib.CHANCE.COMMON, {
	celib.SHOP_TYPE.WEAPON_SHOP,
	celib.SHOP_TYPE.DICESHOP,
	celib.SHOP_TYPE.TUSKDICESHOP,
	celib.SHOP_TYPE.CAVEMAN,
}, true)
celib.add_custom_container_chance(machinegun_id, celib.CHANCE.LOWER, { ENT_TYPE.ITEM_CRATE, ENT_TYPE.ITEM_PRESENT })

celib.init()

register_option_button("machinegun_spawn", "Spawn Heavy Machinegun", "", function()
	if #players == 0 then
		return
	end
	local x, y, l = get_position(players[1].uid)
	celib.set_custom_entity(spawn(ENT_TYPE.ITEM_FREEZERAY, x, y, l, 0, 0), machinegun_id)
end)
