---!strict
---------------------- REFERENCES -----------------------
local TW = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local thunder = script.Thunder

---------------------- BLUEPRINT ---------------------
local radians = {math.rad(90),math.rad(-90)}

local ForkPropertyBuilder = {}
ForkPropertyBuilder.__index = ForkPropertyBuilder
--Creates a new ForkProperty (this one is too big so I seperated it). This helps creating multiple 'forks' or branches like in real bolts
function ForkPropertyBuilder.createBranch(where : CFrame,parent : Instance,chance : number,isFirstBranch : boolean,forkProperty, lightning)
	---handles the branch maker because this is recursive
	--first let's check if the randomness is enough
	local rng = Random.new()
	if rng:NextNumber(0,1) > chance then
		return
	end
	
	local branch = Instance.new("Part")
	--creating the part
	branch.Size = forkProperty.Size
	branch.CFrame = where
	branch.BrickColor = BrickColor.new("New Yeller")
	branch.Material = Enum.Material.Neon
	branch.Anchored = true
	branch.CanCollide = false
	branch.Parent = parent
	Debris:AddItem(branch,lightning.DisappearTime)
	
	--rotates the branch
	local rotation : number = forkProperty.Rotation
	local x = rng:NextNumber(-rotation,rotation)
	local y = rng:NextNumber(-rotation,rotation)
	local z = rng:NextNumber(-rotation,rotation)
	branch.CFrame = where * CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))
	
	if isFirstBranch then
		local x = radians[rng:NextInteger(1,2)]
		local z = radians[rng:NextInteger(1,2)]
		--the first branch's rotation is always large naturally, so that's why add 90 or -90 degrees
		branch.CFrame *= CFrame.Angles(x,0,z)
		
		--so the branch is not stuck in the middle point
		branch.CFrame *= CFrame.new(0,forkProperty.Size.Y/2,0)
		
		--creates other 2 branches
		if forkProperty.Always2Branches then
			--we need to get the tip of the branch
			local tip = branch.CFrame * CFrame.new(0,forkProperty.Size.Y/2,0)
			for i=1,2 do
				ForkPropertyBuilder.createBranch(tip,parent,1,false,forkProperty,lightning)
			end
		end
	else
		branch.CFrame *= CFrame.new(0,forkProperty.Size.Y/2,0)
	end
	
end

function ForkPropertyBuilder.new()
	local ForkProperty = setmetatable({},ForkPropertyBuilder)
	ForkProperty.ChanceOfBranch = 0.3
	ForkProperty.Size = Vector3.new(0.7,2.3,0.7)
	ForkProperty.Rotation = 30
	ForkProperty.Always2Branches = true --appears 2 branches from the first branch, always
	
	return ForkProperty
end

---Creates a thunderstorm, an region that strikes lightning bolts
local Thunderstorm = {}
Thunderstorm.__index = Thunderstorm

--Creates the new thunderstorm (Should not be created through this. Please use lightning:thunderstorm()!)
function Thunderstorm.create(lightning : {},strikeCooldown : number,chanceOfCharHit : number,cframe : CFrame, size : Vector3)
	local thunderstorm = setmetatable({},Thunderstorm)
	
	thunderstorm.CFrame = cframe
	thunderstorm.Size = size
	thunderstorm.Lightning = lightning
	thunderstorm.CharacterHitChance = chanceOfCharHit
	thunderstorm.StrikeCooldown = strikeCooldown
	thunderstorm.Task = nil --the coroutine that handles the lightning storm
	
	return thunderstorm
end
--Starts the thunderstorm.
function Thunderstorm:start()
	self:stop() --Stops the previous thunderstorm if there is any
	
	local da_task = task.spawn(function()
		while true do
			--strikes!
			local lightning = self.Lightning
			local charHitChance : number = self.CharacterHitChance
			local cframe : CFrame = self.CFrame
			local size : Vector3 = self.Size
			
			local rng = Random.new()
			local chance = rng:NextNumber(0,1)
			if chance <= charHitChance then --checks if it is random enough to strike a character down
				local chars = {}
				for _,part in pairs(workspace:GetPartBoundsInBox(cframe,size)) do
					if part and part.Parent and part.Parent:FindFirstChild("Humanoid") then 
						local char = part.Parent
						local humanoid : Humanoid = char.Humanoid
						local primaryPart : BasePart = char.PrimaryPart
						if primaryPart and not chars[primaryPart] then
							--specifically primary part for easier access later on
							table.insert(chars,primaryPart)
						end
					end
				end
				if #chars > 0 then
					local random = chars[rng:NextInteger(1,#chars)]
					lightning:strike(CFrame.new(random.Position))
					task.wait(self.StrikeCooldown)
					
					continue
				else
				--no characters, so we just do the random part later.
				end
			end
			
			--let's get the random position for striking
			local offsetX = rng:NextNumber(-size.X/2,size.X/2)
			local offsetY = -size.Y/2
			local offsetZ = rng:NextNumber(-size.Z/2,size.Z/2)
			local struckCFrame = cframe * CFrame.new(offsetX,offsetY,offsetZ)
			lightning:strike(struckCFrame)
			
			task.wait(self.StrikeCooldown)
		end
	end)
	
	self.Task = da_task
end
--Stops the thunderstorm.
function Thunderstorm:stop()
	if self.Task then
		task.cancel(self.Task)
		self.Task = nil
	end
end

---Time for the Actual Lightning Bolt
local Lightning = {}
Lightning.__index = Lightning

--Creates a new lightning
function Lightning.new(parent : Instance,forkProperty)
	local lightning = setmetatable({},Lightning)
	--The position and rotation of the destinated struck lightning
	lightning.CFrame = CFrame.new(0,0,0)
	lightning.BoltSize = Vector3.new(1,4,1)
	lightning.Bolts = 5
	lightning.Damage = 10
	lightning.Radius = 10
	lightning.DisappearTime = 0.2
	lightning.Rotation = 30
	lightning.AllowsForks = true
	
	if parent then
		lightning.Parent = parent
	else
		lightning.Parent = workspace
	end
	if forkProperty then
		lightning.ForkProperty = forkProperty
	else
		lightning.ForkProperty = ForkPropertyBuilder.new()
	end
	
	return lightning
end

--Deals splash damage and create struck ball visuals. 
function Lightning:createElectricalBall(whereToStrike : CFrame) 
	local radius : number = self.Radius
	local disappearTime : number = self.DisappearTime
	local parent : Instance = self.Parent
	local dmg : number = self.Damage
	--we create a part instead of a direct explosion for deeper customization
	local explosion = Instance.new("Part")
	explosion.Name = "Bolt Explosion"
	explosion.Shape = Enum.PartType.Ball
	explosion.Size = Vector3.new(radius*2,radius*2,radius*2) 
	explosion.BrickColor = BrickColor.new("Toothpaste")
	explosion.Material = Enum.Material.Neon
	explosion.CFrame = whereToStrike
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Parent = parent
	Debris:AddItem(explosion,disappearTime)

	--creating an attachment for thunder roaring
	local att = thunder:Clone()
	att.Parent = parent
	local sound = att.Thunder
	sound:Play()
	sound.Ended:Once(function()
		att:Destroy()
	end)

	--now we deal damage
	local hitCharacters = {} --For preventing the same char multiple times cuz they have more than one part
	for _,part in pairs(workspace:GetPartsInPart(explosion)) do
		if part and part.Parent and part.Parent:FindFirstChildWhichIsA("Humanoid") then
			local char : Model = part.Parent
			if not hitCharacters[char] then
				hitCharacters[char] = true
				local humanoid : Humanoid = part.Parent:FindFirstChildWhichIsA("Humanoid")
				humanoid:TakeDamage(dmg)
			end
		end
	end
end

--Make the lightning strike.
function Lightning:strike(specificLocation : CFrame)
	local size : Vector3 = self.BoltSize
	
	local originalCFrame
	if specificLocation then
		originalCFrame = specificLocation
	else
		originalCFrame = self.CFrame
	end
	
	local disappearTime : number = self.DisappearTime
	local parent : Instance = self.Parent
	local rotation : number = self.Rotation
	local radius : number = self.Radius
	local dmg : number = self.Damage
	local allowsForks : boolean = self.AllowsForks
	local forkProperty = self.ForkProperty
	
	--we need to get the raycasted position, lightnings don't go through things
	local skyCFrame = originalCFrame*CFrame.new(0,500,0)
	local result = workspace:Raycast(skyCFrame.Position,skyCFrame.UpVector* -1 * 500)
	if result then
		originalCFrame = CFrame.new(result.Position) * skyCFrame.Rotation
	end
	
	--doing damages and creating lightning 'explosion' (for splash damage)
	self:createElectricalBall(originalCFrame)
	
	--continously creating smaller bolts for natural look
	local currentCFrame = originalCFrame
	local rng = Random.new()
	
	for i=0,self.Bolts-1,1 do
		--creating the part
		local bolt = Instance.new("Part")
		bolt.Size = size
		bolt.CFrame = currentCFrame
		bolt.BrickColor = BrickColor.new("New Yeller")
		bolt.Material = Enum.Material.Neon
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.Parent = parent
		--now we rotate the bolt randomly
		local x = math.rad(rng:NextNumber(-rotation,rotation)) --generating random intergers
		local y = math.rad(rng:NextNumber(-rotation,rotation))
		local z = math.rad(rng:NextNumber(-rotation,rotation))
		bolt.CFrame = bolt.CFrame * CFrame.Angles(x,y,z) * CFrame.new(0,size.Y/2,0) --set the bolt to its true position
		local tip = (bolt.CFrame * CFrame.new(0,size.Y/2,0)) --getting the top tip cframe of this bolt
		currentCFrame = CFrame.new(tip.Position) * originalCFrame.Rotation
		
		--slowly makes it disappear
		Debris:AddItem(bolt,disappearTime)
		
		--Now we create branches
		if allowsForks then --checks if the lightning allows forks
			ForkPropertyBuilder.createBranch(
				tip,parent,forkProperty.ChanceOfBranch,true,forkProperty,self
			)
		end
	end
end

--Strikes a lightning at a random position in a bounded box
function Lightning:thunderstorm(strikeCooldown : number,chanceOfHitChar : number,cframe : CFrame,size : Vector3)
	local thunderstorm : {} = Thunderstorm.create(self,strikeCooldown,chanceOfHitChar,cframe,size)
	
	if thunderstorm then
		thunderstorm:start()
	end
	
	return thunderstorm
end	

---------------------- LET'S SHOWCASE THIS ---------------------
game.Players.PlayerAdded:Connect(function(plr)  --catches a joining player for their character
	plr.CharacterAdded:Connect(function(char) --gets their character
		local humanoid = char:FindFirstChildWhichIsA("Humanoid")
		--we do not have to check whether it is nil or not, humanoid always load in CharacterAdded
		humanoid.StateChanged:Connect(function(old, new)
			if new == Enum.HumanoidStateType.Jumping then
				--signals the jumping event
				--creates a new fork property
				local forkProperty = ForkPropertyBuilder.new()
				forkProperty.Size = Vector3.new(0.7,5,0.7)
				
				local light = Lightning.new(workspace,forkProperty) --creating a new lightning
				light.Bolts = 18
				light.BoltSize = Vector3.new(1,8,1)
				light.CFrame = CFrame.new(char.PrimaryPart.Position)
				light:strike() --strick!!!
			end
		end)
	end)
end)

---------------------- THUNDERSTORM SHOWCASE ----------------------
local forkProperty = ForkPropertyBuilder.new()
forkProperty.Size = Vector3.new(1,7,1)

local light = Lightning.new(workspace,forkProperty)
light.Bolts = 25
light.BoltSize = Vector3.new(1.2,10,1.2)

local skyPart = workspace.Sky

light:thunderstorm(2,0.7,skyPart.CFrame,skyPart.Size) --chance of hit to 0.7, we have 70% of getting hit while on the green ground
skyPart:Destroy()
