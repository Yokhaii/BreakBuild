return function(CFrame1: CFrame, CFrame2: CFrame): number
	local BetweenCFrame = CFrame1:ToObjectSpace(CFrame2)
	local _, Y, _ = BetweenCFrame:ToOrientation()

	local Angle = math.deg(math.abs(Y))

	return Angle
end
