package funkin.objects;

import animate.FlxAnimate;
import animate.FlxAnimateFrames;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxTileFrames;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxGraphicAsset;
import Paths;

/**
	Global FNF sprite utilities, remade with GPU Texture Compression & robust loading!
**/
class FunkinSprites extends FlxAnimate
{
	public var animOffsets:Map<String, Array<Dynamic>>;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		animOffsets = new Map<String, Array<Dynamic>>();
	}

	public var curAnimateAnim:String = "";

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		curAnimateAnim = AnimName;
		
		if (this.anim != null && this.anim.exists(AnimName))
			this.anim.play(AnimName, Force, Reversed, Frame);
		else if (animation.getByName(AnimName) != null)
			animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
		{
			offset.set(0, 0);
		}
	}
	
	public function getAnimName():String
	{
		if (animation.curAnim != null)
			return animation.curAnim.name;
		return curAnimateAnim;
	}

	public function isAnimFinished():Bool
	{
		if (this.anim != null && this.anim.exists(curAnimateAnim))
			return this.anim.finished;
		if (animation.curAnim != null)
			return animation.curAnim.finished;
		return false;
	}

	public function getAnimList():Array<String>
	{
		var list:Array<String> = [];
		if (this.anim != null && this.anim.getNameList() != null)
		{
			for (animName in this.anim.getNameList())
				list.push(animName);
		}
		if (animation != null && animation.getNameList() != null)
		{
			for (animName in animation.getNameList())
			{
				if (!list.contains(animName))
					list.push(animName);
			}
		}
		return list;
	}

	public function hasAnimation(name:String):Bool
	{
		if (this.anim != null && this.anim.exists(name)) return true;
		return animation.exists(name);
	}

	public function pauseAnim():Void
	{
		if (this.anim != null && this.anim.exists(curAnimateAnim))
			this.anim.pause();
		else if (animation.curAnim != null)
			animation.curAnim.pause();
		else if (animation != null)
			animation.pause();
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	/**
	 * Carrega o Sparrow Atlas direto na GPU usando a compressao configurada!
	 */
	public function loadOptimizedSparrow(key:String, ?library:String, ?textureCompression:Bool = true):FunkinSprites
	{
		// Force texture compression via returnGraphic!
		var graph:FlxGraphic = Paths.returnGraphic(key, library, textureCompression);
		if (graph != null)
		{
			var xml = sys.io.File.getContent(Paths.file('images/$key.xml', library));
			frames = FlxAtlasFrames.fromSparrow(graph, xml);
		}
		return this;
	}
	
	/**
	 * Carrega uma imagem simples direto na GPU usando a compressao configurada!
	 */
	public function loadOptimizedGraphic(key:String, ?library:String, ?textureCompression:Bool = true):FunkinSprites
	{
		var graph:FlxGraphic = Paths.returnGraphic(key, library, textureCompression);
		if (graph != null)
			frames = graph.imageFrame;
			
		return this;
	}

	override public function loadGraphic(Graphic:FlxGraphicAsset, Animated:Bool = false, Width:Int = 0, Height:Int = 0, Unique:Bool = false,
			?Key:String):FunkinSprites
	{
		// Fallback to regular Flixel graphic loading if string isn't provided via optimized methods
		var graph:FlxGraphic = (FlxG.bitmap.add(Graphic, Unique, Key));
		if (graph == null)
			return this;

		if (Width == 0)
		{
			Width = Animated ? graph.height : graph.width;
			Width = (Width > graph.width) ? graph.width : Width;
		}

		if (Height == 0)
		{
			Height = Animated ? Width : graph.height;
			Height = (Height > graph.height) ? graph.height : Height;
		}

		if (Animated)
			frames = FlxTileFrames.fromGraphic(graph, FlxPoint.get(Width, Height));
		else
			frames = graph.imageFrame;

		return this;
	}
}

