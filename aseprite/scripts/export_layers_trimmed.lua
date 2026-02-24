function trimImage(image)
	local w, h = image.width, image.height
	local left, top, right, bottom = w, h, 0, 0

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local pix = image:getPixel(x, y)
			if app.pixelColor.rgbaA(pix) > 0 then
				if x < left then
					left = x
				end
				if y < top then
					top = y
				end
				if x > right then
					right = x
				end
				if y > bottom then
					bottom = y
				end
			end
		end
	end

	if right < left or bottom < top then
		return Image(1, 1), 0, 0
	end

	local newW = right - left + 1
	local newH = bottom - top + 1
	local trimmed = Image(newW, newH)
	trimmed:drawImage(image, Point(-left, -top))
	return trimmed
end

local dlg = Dialog("Export options")
dlg:combobox({
	id = "fmt",
	label = "Output format",
	options = { "PNG", "BMP" },
	option = 1,
})
dlg:check({
	id = "alpha",
	label = "Include alpha channel",
	selected = true,
})
dlg:button({
	text = "Export",
	onclick = function()
		dlg:close()
	end,
})
dlg:show()

local format = dlg.data.fmt
local includeAlpha = dlg.data.alpha

local spr = app.activeSprite
if not spr then
	app.alert("No active sprite loaded.")
	return
end

local basepath = app.fs.filePath(spr.filename)
local basename = app.fs.fileTitle(spr.filename)
local exportDir = app.fs.joinPath(basepath, "export")

if not app.fs.isDirectory(exportDir) then
	app.fs.makeDirectory(exportDir)
end

for i, layer in ipairs(spr.layers) do
	if not layer.isGroup then
		local cel = layer:cel(1)
		if cel and cel.image then
			local img = cel.image:clone()
			local trimmed = trimImage(img)

			local outImage
			if includeAlpha then
				-- Keep alpha as is
				outImage = trimmed
			else
				-- Composite on black to remove alpha
				outImage = Image(trimmed.width, trimmed.height)
				outImage:clear(app.pixelColor.rgba(0, 0, 0, 255))
				outImage:drawImage(trimmed, Point(0, 0))
			end

			local tmp = Sprite(outImage.width, outImage.height)
			tmp.cels[1].image = outImage

			local lname = layer.name:gsub("[^%w_]", "_")
			local ext = string.lower(format)
			local outpath = app.fs.joinPath(exportDir, basename .. "_" .. lname .. "." .. ext)

			tmp:saveCopyAs(outpath)
			tmp:close()
		end
	end
end

app.alert(
	"Exported all layers as trimmed "
		.. format
		.. " files"
		.. (includeAlpha and " with" or " without")
		.. " alpha in 'export/' folder."
)
