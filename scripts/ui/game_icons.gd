class_name GameIcons
extends RefCounted

# Original, shared line icons. Rasterize once at 4x for crisp high-DPI UI.
const PATHS := {
	"paw": '<path d="M8.5 14c1-3 6-3 7 0l2 3c1 3-2 4-5.5 2-3.5 2-6.5 1-5.5-2z"/><ellipse cx="5" cy="10" rx="2" ry="2.6"/><ellipse cx="9.3" cy="5.7" rx="2" ry="2.7"/><ellipse cx="15" cy="5.7" rx="2" ry="2.7"/><ellipse cx="19.3" cy="10" rx="2" ry="2.6"/>',
	"bowl": '<path d="M3 12h18l-2 7H5zM2 19h20M8 8c-2-2 2-2 0-4m8 4c-2-2 2-2 0-4"/>',
	"heart": '<path d="M12 20S3 14 3 8a4.7 4.7 0 0 1 9-2 4.7 4.7 0 0 1 9 2c0 6-9 12-9 12z"/>',
	"ball": '<circle cx="12" cy="12" r="9"/><path d="M5 6c6 0 12 6 12 12M18 5C12 6 6 12 6 18"/>',
	"brush": '<path d="m12 12 7-7a2.1 2.1 0 0 0-3-3l-7 7M5 8l11 11-3 3L2 11zM5 14l-2 2m5 1-2 2m5 1-2 2"/>',
	"moon": '<path d="M19.6 15.8A9 9 0 0 1 8.2 4.4 9 9 0 1 0 19.6 15.8z"/><path d="M17 3v4m-2-2h4"/>',
	"sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
	"spark": '<path d="m12 3 2.8 6.2L21 12l-6.2 2.8L12 21l-2.8-6.2L3 12l6.2-2.8zM20 2v4m-2-2h4"/>',
	"home": '<path d="m3 11 9-8 9 8M5 10v11h14V10M9 21v-7h6v7"/>',
	"book": '<path d="M4 4h7a3 3 0 0 1 3 3v14a4 4 0 0 0-3-2H4zM14 7a3 3 0 0 1 3-3h4v15h-4a4 4 0 0 0-3 2M7 8h3m-3 4h3"/>',
	"settings": '<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2" fill="{bg}"/><circle cx="16" cy="12" r="2" fill="{bg}"/><circle cx="8" cy="18" r="2" fill="{bg}"/>',
	"arrow": '<path d="M5 12h14m-6-6 6 6-6 6"/>',
	"keyboard": '<rect x="2" y="5" width="20" height="14" rx="3"/><path d="M6 9h.1m4 0h.1m4 0h.1m4 0h.1M6 12h.1m4 0h.1m4 0h.1m4 0h.1M7 16h10"/>',
	"treat": '<path d="M9 6a3 3 0 1 0-5 3 3 3 0 1 0 3 5l3 3a3 3 0 1 0 5 3 3 3 0 1 0 3-5z"/>',
	"check": '<path d="m5 12 4 4L19 6"/>'
}
static var _cache: Dictionary = {}

static func texture(key: String, color: Color = Color("24483d")) -> Texture2D:
	var cache_key := key + color.to_html()
	if _cache.has(cache_key): return _cache[cache_key]
	var shape: String = PATHS.get(key, PATHS.paw)
	shape = shape.replace("{bg}", "#fff9ed")
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [color.to_html(false), shape]
	var bitmap := Image.new()
	if bitmap.load_svg_from_string(svg) != OK: return null
	var result := ImageTexture.create_from_image(bitmap)
	_cache[cache_key] = result
	return result
