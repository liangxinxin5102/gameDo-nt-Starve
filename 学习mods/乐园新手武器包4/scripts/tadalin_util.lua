-----����涨�˺ƽپ��ŵ�һЩ����ʶ�����
-----��ȻĿǰΪֹ��û��ʲô����

-------����Ŀ��ѡ��
local function NormalRetarget(inst,radius)
	return FindEntity(
        inst,
        radius or 20,
        function(guy)
            return inst.components.combat:CanTarget(guy)
        end,
        { "_combat","character"},
        {"FX", "NOCLICK","INLIMBO", "monster","hostile","tadalin" }
    )
end

-------�Ƿ��������Ŀ��
local function NormalKeepTarget(inst,target)
	return inst.components.combat:CanTarget(target) 
		and (target.components.health and not target.components.health:IsDead()) 
		and not (inst.components.follower and (inst.components.follower.leader == target or inst.components.follower:IsLeaderSame(target)))
		and not target:HasTag("tadalin")
end

-------�ܵ�����ʱ
local function OnAttacked(inst,data,radius)
	radius = radius or 20 
	local attacker = data.attacker
	inst.components.combat:SuggestTarget(attacker)
	
	inst.components.combat:ShareTarget(attacker, radius, function(dude)
        return  (dude:HasTag("spider") or dude:HasTag("tadalin"))
            and (dude.components.health and not dude.components.health:IsDead()) 
    end,10)
end 

-------�ܹ���target����ֹ����Ҫ����������monster����
local function CanAttack(enemy)
	return enemy and enemy:IsValid() and 
	not (enemy.sg and enemy.sg.currentstate.name == "death") and 
	(
		(enemy:HasTag("player") and not enemy:HasTag("playerghost"))
		or (not enemy:HasTag("monster") and not enemy:HasTag("hostile") and not enemy:HasTag("tadalin")) 
		or ( 
			enemy.components.combat and 
			enemy.components.health and 
			not enemy.components.health:IsDead() and 
			enemy.components.combat.target and 
			enemy.components.combat.target:HasTag("tadalin"))
	)
end

-------��Ϊһ���ƽپ���սʿ�ɣ�
local function MakeNormalTadalin(inst,retargettime)
	inst:AddTag("tadalin")
	
	retargettime = retargettime or 1
	
	inst.components.combat:SetRetargetFunction(retargettime, NormalRetarget)
	inst.components.combat:SetKeepTargetFunction(NormalKeepTarget)
	
	--------------��ֹ��Χ������������monster����
	local oldDoAreaAttack = inst.components.combat.DoAreaAttack
	inst.components.combat.DoAreaAttack = function(self,target, range, weapon, validfn, stimuli, excludetags)
		local old_validfn = validfn
		validfn = function(enemy)
			return (old_validfn == nil or old_validfn(enemy)) and CanAttack(enemy)
		end
		return oldDoAreaAttack(self,target, range, weapon, validfn, stimuli, excludetags)
	end
	--[[local oldDoAttack = inst.components.combat.DoAttack
	inst.components.combat.DoAttack = function(self,target,...)
		if CanAttack(target) then 
			return oldDoAttack(self,target,...)
		else
			self:SetTarget(nil)
		end
	end--]]
	
	inst:ListenForEvent("attacked", OnAttacked)
end


return {
	NormalRetarget = NormalRetarget,
	NormalKeepTarget = NormalKeepTarget,
	OnAttacked = OnAttacked,
	CanAttack = CanAttack,
	MakeNormalTadalin = MakeNormalTadalin,
}