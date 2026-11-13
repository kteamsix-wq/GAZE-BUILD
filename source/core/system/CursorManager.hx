package core.system;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import core.system.Paths;

using StringTools;

/**
 * Native Engine Cursor Manager for Gaze Engine.
 * 
 * Provides unified, engine-wide mouse cursor management with pixel-perfect
 * hotspot / click-point calibration for all custom cursor types.
 */
class CursorManager
{
	// Standard cursor type identifiers
	public static inline var DEFAULT:String = 'default';
	public static inline var POINTER:String = 'pointer';
	public static inline var GRABBING:String = 'grabbing';
	public static inline var CROSS:String = 'cross';
	public static inline var SCROLL:String = 'scroll';
	public static inline var TEXT:String = 'text';
	public static inline var ERASER:String = 'eraser';
	public static inline var HOURGLASS:String = 'hourglass';

	public static inline var DEFAULT_SCALE:Float = 0.70;

	/**
	 * Hotspot definitions (exact pixel coordinate within the 32x32 bitmap
	 * where clicks visually register).
	 *
	 * - default: tip of pointer arrow at (1, 1)
	 * - pointer: index fingertip of pointing hand at (10, 1)
	 * - grabbing: center of clenched fist at (15, 17)
	 * - cross: center of prohibited/cross symbol at (15, 15)
	 * - scroll: center dot of 4-way scroll indicator at (15, 15)
	 * - text: center of I-beam text selector at (15, 15)
	 * - eraser: contact point of angled eraser block at (2, 28)
	 * - hourglass: waist center of hourglass at (15, 15)
	 */
	public static var hotspots:Map<String, {x:Float, y:Float}> = [
		'default' => {x: 1.0, y: 1.0},
		'pointer' => {x: 10.0, y: 1.0},
		'grabbing' => {x: 15.0, y: 17.0},
		'cross' => {x: 15.0, y: 15.0},
		'scroll' => {x: 15.0, y: 15.0},
		'text' => {x: 15.0, y: 15.0},
		'eraser' => {x: 2.0, y: 28.0},
		'hourglass' => {x: 15.0, y: 15.0}
	];

	/**
	 * Cache of loaded cursor BitmapData instances to avoid repeated filesystem lookups.
	 */
	private static var cursorBitmaps:Map<String, BitmapData> = new Map<String, BitmapData>();

	/**
	 * The name of the currently active cursor.
	 */
	public static var currentCursor:String = '';

	/**
	 * Whether the CursorManager has been initialized.
	 */
	public static var initialized:Bool = false;

	/**
	 * Current cursor scale factor (defaults to 0.70 - reduced 30%).
	 */
	public static var currentScale:Float = DEFAULT_SCALE;

	/**
	 * Normalizes a cursor name (e.g. 'cursor-pointer', 'CURSOR_POINTER', 'hand' -> 'pointer').
	 */
	public static function normalizeCursor(name:String):String
	{
		if (name == null || name.length == 0)
			return DEFAULT;

		var clean = name.toLowerCase().trim();

		// Strip common prefixes
		if (clean.startsWith('cursor-'))
			clean = clean.substring(7);
		else if (clean.startsWith('cursor_'))
			clean = clean.substring(7);

		// Handle synonyms/aliases
		switch (clean)
		{
			case 'arrow', 'normal':
				return DEFAULT;
			case 'hand', 'button', 'link':
				return POINTER;
			case 'grab', 'drag', 'fist', 'closedhand':
				return GRABBING;
			case 'crosshair', 'forbidden', 'cancel', 'notallowed', 'no':
				return CROSS;
			case 'pan', 'move', 'autoscroll', 'allscroll':
				return SCROLL;
			case 'ibeam', 'edit':
				return TEXT;
			case 'erase', 'rubber', 'delete':
				return ERASER;
			case 'wait', 'loading', 'busy':
				return HOURGLASS;
		}

		return clean;
	}

	/**
	 * Gets the hotspot point (x, y) for a given cursor type.
	 */
	public static function getHotspot(cursorType:String):{x:Float, y:Float}
	{
		var clean = normalizeCursor(cursorType);
		if (hotspots.exists(clean))
			return hotspots.get(clean);
		return {x: 0.0, y: 0.0};
	}

	/**
	 * Gets the FlxMouse drawing offset (-hotspot.x * scale, -hotspot.y * scale)
	 * for a given cursor type and scale factor with pixel-perfect rounding.
	 */
	public static function getOffset(cursorType:String, ?scale:Null<Float> = null):{x:Int, y:Int}
	{
		var sc:Float = (scale != null && scale > 0) ? scale : currentScale;
		var spot = getHotspot(cursorType);
		return {
			x: -Math.round(spot.x * sc),
			y: -Math.round(spot.y * sc)
		};
	}

	/**
	 * Retrieves or loads the BitmapData for a cursor type.
	 * Searches UI/cursor first, then falls back to menus/editors.
	 */
	public static function getBitmap(cursorType:String):Null<BitmapData>
	{
		var clean = normalizeCursor(cursorType);
		if (cursorBitmaps.exists(clean))
		{
			var cached = cursorBitmaps.get(clean);
			if (cached != null)
				return cached;
		}

		var candidatePaths:Array<String> = [
			'UI/cursor/cursor-' + clean,
			'UI/cursor/' + clean,
			'menus/editors/cursor-' + clean,
			'menus/editors/' + clean
		];

		var graphic:FlxGraphic = null;
		for (path in candidatePaths)
		{
			graphic = Paths.image(path, null, false);
			if (graphic != null && graphic.bitmap != null)
				break;
		}

		if (graphic != null && graphic.bitmap != null)
		{
			cursorBitmaps.set(clean, graphic.bitmap);
			return graphic.bitmap;
		}

		return null;
	}

	/**
	 * Initializes the cursor manager, making the custom engine cursor active and visible.
	 */
	public static function init():Void
	{
		registerDumpExclusions();
		preloadAll();

		FlxG.mouse.useSystemCursor = false;
		FlxG.mouse.visible = true;
		FlxG.mouse.enabled = true;

		currentScale = DEFAULT_SCALE;
		change(DEFAULT, true, DEFAULT_SCALE);
		initialized = true;
	}

	/**
	 * Registers cursor assets in dump exclusions so FunkinMemory never purges them.
	 */
	public static function registerDumpExclusions():Void
	{
		var cursorTypes:Array<String> = [DEFAULT, POINTER, GRABBING, CROSS, SCROLL, TEXT, ERASER, HOURGLASS];
		for (cur in cursorTypes)
		{
			Paths.excludeAsset('assets/images/UI/cursor/cursor-' + cur + '.png');
			Paths.excludeAsset('assets/images/menus/editors/cursor-' + cur + '.png');
		}
	}

	/**
	 * Preloads all standard cursor bitmaps to prevent runtime frame hitching.
	 */
	public static function preloadAll():Void
	{
		var cursorTypes:Array<String> = [DEFAULT, POINTER, GRABBING, CROSS, SCROLL, TEXT, ERASER, HOURGLASS];
		for (cur in cursorTypes)
		{
			getBitmap(cur);
		}
	}

	/**
	 * Changes the mouse cursor to the specified cursor type with accurate click point offset.
	 * 
	 * @param cursorType Identifier (e.g. 'default', 'pointer', 'grabbing', 'cursor-cross', etc.)
	 * @param force If true, forces reload even if cursorType matches currentCursor.
	 * @param scale Cursor scale factor (defaults to DEFAULT_SCALE: 0.70).
	 */
	public static function change(cursorType:String = DEFAULT, force:Bool = false, ?scale:Null<Float> = null):Void
	{
		var clean = normalizeCursor(cursorType);
		var daScale:Float = (scale != null && scale > 0) ? scale : DEFAULT_SCALE;

		if (!force && currentCursor == clean && Math.abs(daScale - currentScale) < 0.001 && FlxG.mouse.cursor != null)
			return;

		var bmp = getBitmap(clean);
		var offset = getOffset(clean, daScale);

		if (bmp != null)
		{
			FlxG.mouse.useSystemCursor = false;
			FlxG.mouse.load(bmp, daScale, offset.x, offset.y);
			currentCursor = clean;
			currentScale = daScale;
		}
		else
		{
			FlxG.mouse.useSystemCursor = true;
			currentCursor = clean;
			currentScale = daScale;
		}
	}

	/**
	 * Resets cursor to the engine default arrow cursor at DEFAULT_SCALE.
	 */
	public static function reset(?force:Bool = false):Void
	{
		change(DEFAULT, force, DEFAULT_SCALE);
	}

	/**
	 * Toggles or checks mouse cursor visibility.
	 */
	public static var visible(get, set):Bool;
	static inline function get_visible():Bool return FlxG.mouse.visible;
	static inline function set_visible(v:Bool):Bool return FlxG.mouse.visible = v;

	/**
	 * Shows the engine cursor, ensuring it is properly loaded and scaled.
	 */
	public static inline function show():Void
	{
		FlxG.mouse.visible = true;
		change(currentCursor != '' ? currentCursor : DEFAULT, true, DEFAULT_SCALE);
	}

	/**
	 * Hides the engine cursor.
	 */
	public static inline function hide():Void
	{
		FlxG.mouse.visible = false;
	}
}
