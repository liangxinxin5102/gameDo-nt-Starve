local ParryWeapon = Class(function(self, inst)
	self.inst = inst 
	--self.parry_damage = 0
	--self.max_parry_damage = 200
	
	inst:AddTag("parryweapon")
end)

function ParryWeapon:TryParry(player, attacker, damage, weapon, stimuli)
	if not attacker then 
		return 
	end
	local myangle = player.Transform:GetRotation() ---get�ҵĽǶ�
	local attackerangle = player:GetAngleToPoint(attacker.Transform:GetWorldPosition()) ---get�ҵ�Ŀ��ĽǶ�
	local deltaangle = math.abs(myangle - attackerangle)----�ǶȲ�
	print(string.format("[ParryWeapon]: myangle = %.2f attackerangle = %.2f deltaangle = %.2f",myangle,attackerangle,deltaangle))
	return player.sg:HasStateTag("parrying") and  deltaangle <= 75 and stimuli ~= "electric" 
end

function ParryWeapon:OnPreParry(player)
	
end

return ParryWeapon


