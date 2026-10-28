package funkin.editors.camera;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.addons.display.FlxSliceSprite;
import backend.Conductor;
import backend.CoolUtil;
import funkin.objects.Character;
import funkin.objects.Boyfriend;
import funkin.objects.Stage;
import Paths;

using StringTools;

/**
 * Renders the Virtual Camera viewport rectangle, corners, crosshairs,
 * widescreen extended bounds, and passepartout letterbox mask.
 * Faithful port from Friday Night Funkin' V-Slice.
 */
class VirtualCameraRectangle extends FlxSpriteGroup
{
	public var zoom(get, set):Float;
	private var _zoom:Float = 1.0;

	public var relativeZoom:Float = 1.0;
	public var vcamPoint:FlxPoint = new FlxPoint();
	public var scrollTarget:FlxPoint = new FlxPoint();

	public var currentStage:Stage;
	public var boyfriend:Boyfriend;
	public var dad:Character;
	public var gf:Character;

	public var cachedBfPoint:FlxPoint = new FlxPoint();
	public var cachedDadPoint:FlxPoint = new FlxPoint();
	public var cachedGfPoint:FlxPoint = new FlxPoint();
	public var hasCachedPoints:Bool = false;

	public var isRelative(default, set):Bool = false;
	public var showExtendedBounds(default, set):Bool = false;
	public var showPassepartout(default, set):Bool = false;
	public var passepartoutTransparency(default, set):Float = 0.6;
	public var doBopping:Bool = false;

	public var hudZoom:Float = 1.0;
	public var cameraZoomRate:Float = 4.0; // Bops every 4 steps (1 beat)
	public var cameraBopIntensity:Float = 0.03;

	// Follow and Zoom tweens
	public var cameraFollowPoint:FlxObject = new FlxObject();
	var cameraFollowTween:Float = 0;
	var cameraFollowStart:FlxPoint = new FlxPoint();
	var cameraFollowDuration:Float = 0;
	var cameraFollowEase:Null<Float->Float> = null;
	var isClassicEase:Bool = false;

	var cameraZoomTween:Float = 0;
	var cameraZoomStart:Float = 1.0;
	var cameraZoomEnd:Float = 1.0;
	var cameraZoomDuration:Float = 0;
	var cameraZoomEase:Null<Float->Float> = null;
	var isClassicZoom:Bool = false;

	var forceNextFocus:Bool = false;

	// Sprites
	var mainView:FlxSprite;
	var camSlice:FlxSliceSprite;
	var camSliceOverlay:FlxSliceSprite;

	var cornerTL:FlxSprite;
	var cornerTR:FlxSprite;
	var cornerBL:FlxSprite;
	var cornerBR:FlxSprite;

	var cornerTLSmall:FlxSprite;
	var cornerTRSmall:FlxSprite;
	var cornerBLSmall:FlxSprite;
	var cornerBRSmall:FlxSprite;

	var lineT:FlxSprite;
	var lineB:FlxSprite;
	var lineL:FlxSprite;
	var lineR:FlxSprite;

	var lineLSmall:FlxSprite;
	var lineRSmall:FlxSprite;

	var middle:FlxSprite;

	var leftExt:FlxSliceSprite;
	var rightExt:FlxSliceSprite;
	var pieceSize:Float = 0;

	var passeT:FlxSprite;
	var passeB:FlxSprite;
	var passeL:FlxSprite;
	var passeR:FlxSprite;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		// 1. Passepartout letterbox borders (1x1 scaled black sprites - saves ~90MB VRAM)
		passeT = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		passeT.scale.set(FlxG.width * 3, FlxG.height * 2);
		passeT.updateHitbox();

		passeB = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		passeB.scale.set(FlxG.width * 3, FlxG.height * 2);
		passeB.updateHitbox();

		passeL = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		passeL.scale.set(FlxG.width * 2, FlxG.height * 3);
		passeL.updateHitbox();

		passeR = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		passeR.scale.set(FlxG.width * 2, FlxG.height * 3);
		passeR.updateHitbox();

		for (p in [passeT, passeB, passeL, passeR])
		{
			p.alpha = passepartoutTransparency;
			p.visible = false;
			add(p);
		}

		// 2. Main View Box (invisible frame reference)
		mainView = new FlxSprite().makeGraphic(1, 1, FlxColor.BLUE);
		mainView.scale.set(FlxG.width, FlxG.height);
		mainView.updateHitbox();
		mainView.visible = false;
		add(mainView);

		// 16:9 / 21:9 extension calculation
		pieceSize = ((FlxG.width / 16.0 * 21.0) - FlxG.width) / 2.0;

		// 3. Slice Sprites
		var sliceRect = new FlxRect(30, 30, 30, 30);

		leftExt = new FlxSliceSprite(Paths.image('menus/editors/camera/vcam/vcam_slice_left'), sliceRect, pieceSize, FlxG.height);
		leftExt.alpha = 0.35;
		leftExt.color = 0xFF7ABF9B;
		leftExt.visible = false;
		add(leftExt);

		rightExt = new FlxSliceSprite(Paths.image('menus/editors/camera/vcam/vcam_slice_right'), sliceRect, pieceSize, FlxG.height);
		rightExt.alpha = 0.35;
		rightExt.color = 0xFF7ABF9B;
		rightExt.visible = false;
		add(rightExt);

		camSliceOverlay = new FlxSliceSprite(Paths.image('menus/editors/camera/vcam/vcam_slice_solid'), sliceRect, FlxG.width, FlxG.height);
		camSliceOverlay.alpha = 0.15;
		camSliceOverlay.color = 0xFF7ABFBC;
		add(camSliceOverlay);

		camSlice = new FlxSliceSprite(Paths.image('menus/editors/camera/vcam/vcam_slice'), sliceRect, FlxG.width, FlxG.height);
		camSlice.alpha = 0.55;
		camSlice.color = 0xFF7ABFBC;
		add(camSlice);

		// 4. Center Crosshair
		middle = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_center'));
		add(middle);

		// 5. Corners
		cornerTL = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner'));
		cornerTR = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner'));
		cornerBL = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner'));
		cornerBR = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner'));

		cornerTR.flipX = true;
		cornerBR.flipX = true;
		cornerBR.flipY = true;
		cornerBL.flipY = true;

		// 6. Outer small corners
		cornerTLSmall = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner_small'));
		cornerTRSmall = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner_small'));
		cornerBLSmall = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner_small'));
		cornerBRSmall = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_corner_small'));

		cornerTRSmall.flipX = true;
		cornerBRSmall.flipX = true;
		cornerBRSmall.flipY = true;
		cornerBLSmall.flipY = true;

		// 7. Lines
		lineT = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_line_horizontal'));
		lineB = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_line_horizontal'));
		lineB.flipX = true;

		lineL = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_line_vertical'));
		lineR = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_line_vertical'));
		lineR.flipY = true;

		lineLSmall = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_line_small'));
		lineRSmall = new FlxSprite().loadGraphic(Paths.image('menus/editors/camera/vcam/vcam_line_small'));
		lineRSmall.flipY = true;

		var borderSprites:Array<FlxSprite> = [
			cornerTL, cornerTR, cornerBL, cornerBR,
			cornerTLSmall, cornerTRSmall, cornerBLSmall, cornerBRSmall,
			lineT, lineB, lineL, lineR, lineLSmall, lineRSmall
		];

		for (spr in borderSprites)
		{
			spr.color = 0xFF000000;
			add(spr);
		}

		for (spr in [cornerTLSmall, cornerTRSmall, cornerBLSmall, cornerBRSmall, lineLSmall, lineRSmall])
		{
			spr.visible = false;
			spr.alpha = 0.7;
		}

		resize();
	}

	function get_zoom():Float
	{
		if (!doBopping) return _zoom;
		return _zoom + (hudZoom - 1.0);
	}

	function set_zoom(val:Float):Float
	{
		_zoom = val;
		resize();
		return _zoom;
	}

	function set_isRelative(val:Bool):Bool
	{
		isRelative = val;
		resize();
		return isRelative;
	}

	function set_showExtendedBounds(val:Bool):Bool
	{
		showExtendedBounds = val;
		leftExt.visible = val;
		rightExt.visible = val;
		cornerTLSmall.visible = val;
		cornerTRSmall.visible = val;
		cornerBLSmall.visible = val;
		cornerBRSmall.visible = val;
		lineLSmall.visible = val;
		lineRSmall.visible = val;
		return showExtendedBounds;
	}

	function set_showPassepartout(val:Bool):Bool
	{
		showPassepartout = val;
		for (p in [passeT, passeB, passeL, passeR])
			p.visible = val;

		camSliceOverlay.visible = !val;

		var sprColor:FlxColor = val ? 0xFFFFFFFF : 0xFF000000;
		for (spr in [
			cornerTL, cornerTR, cornerBL, cornerBR,
			cornerTLSmall, cornerTRSmall, cornerBLSmall, cornerBRSmall,
			lineT, lineB, lineL, lineR, lineLSmall, lineRSmall
		])
		{
			spr.color = sprColor;
		}

		leftExt.loadGraphic(val ? Paths.image('menus/editors/camera/vcam/vcam_slice_cutout_left') : Paths.image('menus/editors/camera/vcam/vcam_slice_left'));
		rightExt.loadGraphic(val ? Paths.image('menus/editors/camera/vcam/vcam_slice_cutout_right') : Paths.image('menus/editors/camera/vcam/vcam_slice_right'));
		camSlice.loadGraphic(val ? Paths.image('menus/editors/camera/vcam/vcam_slice_cutout') : Paths.image('menus/editors/camera/vcam/vcam_slice'));

		return showPassepartout;
	}

	function set_passepartoutTransparency(val:Float):Float
	{
		passepartoutTransparency = val;
		for (p in [passeT, passeB, passeL, passeR])
			p.alpha = val;
		return passepartoutTransparency;
	}

	public function resize():Void
	{
		var w = isRelative ? FlxG.width : (FlxG.width / Math.max(0.01, _zoom));
		var h = isRelative ? FlxG.height : (FlxG.height / Math.max(0.01, _zoom));

		mainView.setGraphicSize(Std.int(w), Std.int(h));
		mainView.updateHitbox();

		camSlice.width = w;
		camSlice.height = h;

		camSliceOverlay.width = w;
		camSliceOverlay.height = h;
	}

	public function cacheIdleCameraPoints():Void
	{
		if (boyfriend != null)
		{
			var mid = boyfriend.getMidpoint();
			var ox:Float = (boyfriend.characterData != null) ? boyfriend.characterData.camOffsetX : (boyfriend.cameraPosition != null ? boyfriend.cameraPosition[0] : 0.0);
			var oy:Float = (boyfriend.characterData != null) ? boyfriend.characterData.camOffsetY : (boyfriend.cameraPosition != null ? boyfriend.cameraPosition[1] : 0.0);
			cachedBfPoint.set(mid.x - ox, mid.y + oy);
			mid.put();
		}
		else
		{
			cachedBfPoint.set(770, 450);
		}

		if (dad != null)
		{
			var mid = dad.getMidpoint();
			var ox:Float = (dad.characterData != null) ? dad.characterData.camOffsetX : (dad.cameraPosition != null ? dad.cameraPosition[0] : 0.0);
			var oy:Float = (dad.characterData != null) ? dad.characterData.camOffsetY : (dad.cameraPosition != null ? dad.cameraPosition[1] : 0.0);
			cachedDadPoint.set(mid.x + ox, mid.y + oy);
			mid.put();
		}
		else
		{
			cachedDadPoint.set(100, 100);
		}

		var targetGf:Character = (gf != null) ? gf : dad;
		if (targetGf != null)
		{
			var mid = targetGf.getMidpoint();
			var ox:Float = (targetGf.characterData != null) ? targetGf.characterData.camOffsetX : (targetGf.cameraPosition != null ? targetGf.cameraPosition[0] : 0.0);
			var oy:Float = (targetGf.characterData != null) ? targetGf.characterData.camOffsetY : (targetGf.cameraPosition != null ? targetGf.cameraPosition[1] : 0.0);
			cachedGfPoint.set(mid.x + ox, mid.y + oy);
			mid.put();
		}
		else
		{
			cachedGfPoint.set(400, 130);
		}

		hasCachedPoints = true;
	}

	public function getCharacterCameraPoint(target:Int):FlxPoint
	{
		if (!hasCachedPoints)
			cacheIdleCameraPoints();

		var pt = FlxPoint.get();
		switch (target)
		{
			case 0: // Boyfriend
				pt.copyFrom(cachedBfPoint);
			case 1: // Dad / Opponent
				pt.copyFrom(cachedDadPoint);
			case 2: // Girlfriend
				pt.copyFrom(cachedGfPoint);
			default:
				pt.set(0, 0);
		}
		return pt;
	}

	public function getDefaultPosition():FlxPoint
	{
		if (dad != null)
			return getCharacterCameraPoint(1);
		if (boyfriend != null)
			return getCharacterCameraPoint(0);
		return FlxPoint.get(FlxG.width / 2, FlxG.height / 2);
	}

	public function cancelAllTweens():Void
	{
		cameraFollowTween = 0;
		cameraFollowDuration = 0;
		cameraFollowEase = null;
		isClassicEase = false;

		cameraZoomTween = 0;
		cameraZoomDuration = 0;
		cameraZoomEase = null;
		isClassicZoom = false;
	}

	public function setFocusPoint(x:Float, y:Float, snap:Bool = false):Void
	{
		cameraFollowPoint.x = x;
		cameraFollowPoint.y = y;
		scrollTarget.set(x - (FlxG.width / 2.0), y - (FlxG.height / 2.0));
		if (snap)
		{
			vcamPoint.copyFrom(scrollTarget);
			forceNextFocus = true;
			updateVisuals();
		}
	}

	public function focusOnTarget(target:Int, ?offX:Float = 0, ?offY:Float = 0, ?ease:String = "CLASSIC", ?duration:Float = 4.0, ?snap:Bool = false):Void
	{
		var basePt:FlxPoint;
		if (target >= 0 && target <= 2)
		{
			basePt = getCharacterCameraPoint(target);
		}
		else
		{
			basePt = FlxPoint.get(0, 0);
		}

		var tx:Float = basePt.x + offX;
		var ty:Float = basePt.y + offY;
		basePt.put();

		cameraFollowPoint.x = tx;
		cameraFollowPoint.y = ty;
		scrollTarget.set(tx - (FlxG.width / 2.0), ty - (FlxG.height / 2.0));

		var easeStr:String = (ease != null) ? ease.trim() : "CLASSIC";
		var upperEase:String = easeStr.toUpperCase();
		if (snap || upperEase == "INSTANT" || duration <= 0)
		{
			cancelAllTweens();
			vcamPoint.copyFrom(scrollTarget);
			forceNextFocus = true;
			updateVisuals();
			return;
		}

		if (upperEase == "CLASSIC")
		{
			cancelAllTweens();
			isClassicEase = true;
			cameraFollowTween = Conductor.songPosition;
			cameraFollowStart.copyFrom(vcamPoint);
			return;
		}

		// Duration in seconds (steps * stepCrochet / 1000)
		var durSec:Float = (duration * Conductor.stepCrochet) / 1000.0;
		var easeFunc = CoolUtil.getEaseFromString(easeStr);

		cancelAllTweens();
		cameraFollowTween = Conductor.songPosition;
		cameraFollowStart.copyFrom(vcamPoint);
		cameraFollowDuration = durSec;
		cameraFollowEase = easeFunc;
	}

	public function handleFocusCamera(event:CameraEditorEvent):Void
	{
		focusOnTarget(event.target, event.x, event.y, event.ease, event.duration, false);
	}

	public function handleZoomCamera(stageZoom:Float, event:CameraEditorEvent):Void
	{
		var targetZ:Float = event.zoom;
		if (event.mode == "stage")
			targetZ *= stageZoom;

		var easeStr:String = (event.ease != null) ? event.ease.trim() : "linear";
		var upperEase:String = easeStr.toUpperCase();
		if (upperEase == "INSTANT" || event.duration <= 0)
		{
			cameraZoomTween = 0;
			cameraZoomEase = null;
			isClassicZoom = false;
			this.zoom = targetZ;
			return;
		}

		var durSec:Float = (event.duration * Conductor.stepCrochet) / 1000.0;
		var easeFunc = CoolUtil.getEaseFromString(easeStr);

		cameraZoomTween = Conductor.songPosition;
		cameraZoomStart = _zoom;
		cameraZoomEnd = targetZ;
		cameraZoomDuration = durSec;
		cameraZoomEase = easeFunc;
		isClassicZoom = false;
	}

	public function triggerBop():Void
	{
		hudZoom = 1.0 + cameraBopIntensity;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Camera Bop decay
		if (doBopping)
		{
			hudZoom = FlxMath.lerp(1.0, hudZoom, Math.exp(-elapsed * 9.0));
		}
		else
		{
			hudZoom = 1.0;
		}

		scrollTarget.set(cameraFollowPoint.x - (FlxG.width / 2.0), cameraFollowPoint.y - (FlxG.height / 2.0));

		if (forceNextFocus)
		{
			vcamPoint.copyFrom(scrollTarget);
			forceNextFocus = false;
		}
		else if (!isClassicEase && cameraFollowEase == null)
		{
			vcamPoint.copyFrom(scrollTarget);
		}

		// Follow Tween
		if (isClassicEase)
		{
			var dtMs:Float = Math.max(0, Conductor.songPosition - cameraFollowTween);
			var progress:Float = FlxMath.bound(1.0 - Math.pow(1.0 - 0.04, dtMs / 1000.0 * 60.0), 0.0, 1.0);
			vcamPoint.x = FlxMath.lerp(cameraFollowStart.x, scrollTarget.x, progress);
			vcamPoint.y = FlxMath.lerp(cameraFollowStart.y, scrollTarget.y, progress);

			if (progress >= 0.999)
			{
				vcamPoint.copyFrom(scrollTarget);
				isClassicEase = false;
			}
		}
		else if (cameraFollowEase != null && cameraFollowDuration > 0)
		{
			var dtMs:Float = Conductor.songPosition - cameraFollowTween;
			var t:Float = FlxMath.bound(dtMs / (cameraFollowDuration * 1000.0), 0.0, 1.0);
			var progress:Float = cameraFollowEase(t);
			vcamPoint.x = FlxMath.lerp(cameraFollowStart.x, scrollTarget.x, progress);
			vcamPoint.y = FlxMath.lerp(cameraFollowStart.y, scrollTarget.y, progress);

			if (t >= 1.0)
			{
				vcamPoint.copyFrom(scrollTarget);
				cameraFollowEase = null;
			}
		}

		// Zoom Tween
		if (cameraZoomEase != null && cameraZoomDuration > 0)
		{
			var dtMs:Float = Conductor.songPosition - cameraZoomTween;
			var t:Float = FlxMath.bound(dtMs / (cameraZoomDuration * 1000.0), 0.0, 1.0);
			var progress:Float = cameraZoomEase(t);
			this.zoom = FlxMath.lerp(cameraZoomStart, cameraZoomEnd, progress);

			if (t >= 1.0)
			{
				this.zoom = cameraZoomEnd;
				cameraZoomEase = null;
			}
		}

		updateVisuals();
	}

	public function updateVisuals():Void
	{
		var vx:Float = vcamPoint.x;
		var vy:Float = vcamPoint.y;

		mainView.x = (vx + (FlxG.width / 2.0)) - mainView.width / 2.0;
		mainView.y = (vy + (FlxG.height / 2.0)) - mainView.height / 2.0;

		camSlice.x = mainView.x;
		camSlice.y = mainView.y;
		camSliceOverlay.x = mainView.x;
		camSliceOverlay.y = mainView.y;

		// Corners
		cornerTL.setPosition(mainView.x, mainView.y);
		cornerTR.setPosition(mainView.x + mainView.width - cornerTR.width, mainView.y);
		cornerBL.setPosition(mainView.x, mainView.y + mainView.height - cornerBL.height);
		cornerBR.setPosition(mainView.x + mainView.width - cornerBR.width, mainView.y + mainView.height - cornerBR.height);

		// Edges
		lineT.setPosition(mainView.x + (mainView.width - lineT.width) / 2.0, mainView.y);
		lineB.setPosition(mainView.x + (mainView.width - lineB.width) / 2.0, mainView.y + mainView.height - lineB.height);
		lineL.setPosition(mainView.x, mainView.y + (mainView.height - lineL.height) / 2.0);
		lineR.setPosition(mainView.x + mainView.width - lineR.width, mainView.y + (mainView.height - lineR.height) / 2.0);

		// Center
		middle.setPosition(mainView.x + (mainView.width - middle.width) / 2.0, mainView.y + (mainView.height - middle.height) / 2.0);

		// Extended Bounds
		var curExtWidth:Float = isRelative ? pieceSize : (pieceSize / Math.max(0.01, _zoom));
		leftExt.width = curExtWidth;
		leftExt.height = camSlice.height;
		leftExt.setPosition(camSlice.x - leftExt.width, camSlice.y);

		rightExt.width = curExtWidth;
		rightExt.height = camSlice.height;
		rightExt.setPosition(camSlice.x + camSlice.width, camSlice.y);

		cornerTLSmall.setPosition(leftExt.x, leftExt.y);
		cornerBLSmall.setPosition(leftExt.x, leftExt.y + leftExt.height - cornerBLSmall.height);
		cornerTRSmall.setPosition(rightExt.x + rightExt.width - cornerTRSmall.width, rightExt.y);
		cornerBRSmall.setPosition(rightExt.x + rightExt.width - cornerBRSmall.width, rightExt.y + rightExt.height - cornerBRSmall.height);

		lineLSmall.setPosition(leftExt.x, leftExt.y + (leftExt.height - lineLSmall.height) / 2.0);
		lineRSmall.setPosition(rightExt.x + rightExt.width - lineRSmall.width, rightExt.y + (rightExt.height - lineRSmall.height) / 2.0);

		// Passepartout
		if (!showPassepartout) return;

		var extraW:Float = showExtendedBounds ? curExtWidth : 0.0;
		passeT.setPosition(mainView.x + (mainView.width - passeT.width) / 2.0, mainView.y - passeT.height);
		passeB.setPosition(mainView.x + (mainView.width - passeB.width) / 2.0, mainView.y + mainView.height);
		passeL.setPosition(mainView.x - passeL.width - extraW, mainView.y + (mainView.height - passeL.height) / 2.0);
		passeR.setPosition(mainView.x + mainView.width + extraW, mainView.y + (mainView.height - passeR.height) / 2.0);
	}
}
