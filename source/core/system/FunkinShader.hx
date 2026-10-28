package backend;

import flixel.addons.display.FlxRuntimeShader;
import openfl.display.ShaderParameter;
import openfl.display.ShaderInput;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import haxe.ds.ObjectMap;
import sys.io.File;
import sys.FileSystem;
import Paths;

/**
 * Sistema de Shader baseado na Codename Engine.
 * Usando um Abstract para permitir modificar uniforms dinamicamente via propriedades:
 * Ex: shader.time = 1.0;
 */
@:forward
abstract FunkinShader(FunkinShaderImpl) from FunkinShaderImpl to FunkinShaderImpl
{
	public inline function new(?fragmentSource:String, ?vertexSource:String, ?version:String)
	{
		this = new FunkinShaderImpl(fragmentSource, vertexSource, version);
	}

	/**
	 * Carrega um shader a partir de um arquivo (usado muito na Codename Engine)
	 * @param fragmentPath Caminho para o shader de fragmento (.frag)
	 * @param vertexPath Caminho para o shader de vértice (.vert). Se nulo, usará o mesmo nome do fragmento.
	 * @param version Versão do GLSL
	 */
	public static inline function fromFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShader
	{
		return FunkinShaderImpl.fromFile(fragmentPath, vertexPath, version);
	}

	@:op(a.b)
	public function set(name:String, value:Dynamic):Dynamic
	{
		var prop:Dynamic = this.data != null ? Reflect.field(this.data, name) : null;
		if (prop != null)
		{
			if (Std.isOfType(value, Array)) {
				prop.value = value;
			} else if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
				var flt:Float = Std.parseFloat(Std.string(value));
				prop.value = [flt];
			} else {
				prop.value = [value];
			}
			return value;
		}
		
		Reflect.setProperty(this, name, value);
		return value;
	}

	@:op(a.b)
	public function get(name:String):Dynamic
	{
		var prop:Dynamic = this.data != null ? Reflect.field(this.data, name) : null;
		if (prop != null)
		{
			var val:Array<Dynamic> = prop.value;
			if (val != null) {
				return val.length == 1 ? val[0] : val;
			}
			return null;
		}
		
		return Reflect.getProperty(this, name);
	}
}

/**
 * A classe base interna que faz o trabalho real.
 */
class FunkinShaderImpl extends FlxRuntimeShader
{
	public var activeTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	private static var _genericShaderTweens:ObjectMap<Dynamic, Map<String, FlxTween>> = new ObjectMap<Dynamic, Map<String, FlxTween>>();

	public function new(?fragmentSource:String, ?vertexSource:String, ?version:String)
	{
		super(fragmentSource, vertexSource);
		initUniformDefaults();
	}

	public function getUniformValue(name:String, defaultValue:Float = 0.0):Float
	{
		if (data != null)
		{
			var prop:Dynamic = Reflect.field(data, name);
			if (prop != null && prop.value != null && prop.value.length > 0)
			{
				var v:Dynamic = prop.value[0];
				if (v != null) return Std.parseFloat(Std.string(v));
			}
		}
		return defaultValue;
	}

	public function setUniformValue(name:String, value:Float):Void
	{
		if (data != null)
		{
			var prop:Dynamic = Reflect.field(data, name);
			if (prop != null)
			{
				prop.value = [value];
				return;
			}
		}
		try
		{
			setFloat(name, value);
		}
		catch (e:Dynamic) {}
	}

	public function cancelTween(?property:String):Void
	{
		if (property != null)
		{
			var twn = activeTweens.get(property);
			if (twn != null)
			{
				twn.cancel();
				activeTweens.remove(property);
			}
		}
		else
		{
			for (twn in activeTweens)
			{
				if (twn != null) twn.cancel();
			}
			activeTweens.clear();
		}
	}

	/**
	 * Dá tween em um uniforme do shader.
	 * Suporta:
	 * - shader.tween("prop", valorFinal, duracao, {ease: FlxEase.cubeOut})
	 * - shader.tween("prop", valorFinal, duracao, FlxEase.cubeOut)
	 * - shader.tween("prop", valorInicial, valorFinal, duracao, {ease: FlxEase.cubeOut})
	 */
	public function tween(property:String, arg1:Float, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic):FlxTween
	{
		return tweenAnyShader(this, property, arg1, arg2, arg3, arg4, arg5);
	}

	public static function getShaderUniform(shader:Dynamic, property:String, defaultValue:Float = 0.0):Float
	{
		if (shader == null) return defaultValue;
		if (Std.isOfType(shader, FunkinShaderImpl))
		{
			return cast(shader, FunkinShaderImpl).getUniformValue(property, defaultValue);
		}

		if (shader.data != null)
		{
			var prop:Dynamic = Reflect.field(shader.data, property);
			if (prop != null && prop.value != null && prop.value.length > 0)
			{
				var v:Dynamic = prop.value[0];
				if (v != null) return Std.parseFloat(Std.string(v));
			}
		}
		return defaultValue;
	}

	public static function setShaderUniform(shader:Dynamic, property:String, value:Float):Void
	{
		if (shader == null) return;
		if (Std.isOfType(shader, FunkinShaderImpl))
		{
			cast(shader, FunkinShaderImpl).setUniformValue(property, value);
			return;
		}

		if (shader.data != null)
		{
			var prop:Dynamic = Reflect.field(shader.data, property);
			if (prop != null)
			{
				prop.value = [value];
				return;
			}
		}

		if (Reflect.hasField(shader, "setFloat"))
		{
			try
			{
				shader.setFloat(property, value);
			}
			catch (e:Dynamic) {}
		}
	}

	public static function cancelAnyShaderTween(shader:Dynamic, ?property:String):Void
	{
		if (shader == null) return;

		if (Std.isOfType(shader, FunkinShaderImpl))
		{
			cast(shader, FunkinShaderImpl).cancelTween(property);
			return;
		}

		var map = _genericShaderTweens.get(shader);
		if (map == null) return;

		if (property != null)
		{
			var twn = map.get(property);
			if (twn != null)
			{
				twn.cancel();
				map.remove(property);
			}
		}
		else
		{
			for (twn in map)
			{
				if (twn != null) twn.cancel();
			}
			map.clear();
			_genericShaderTweens.remove(shader);
		}
	}

	public static function tweenAnyShader(shader:Dynamic, property:String, arg1:Float, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic):FlxTween
	{
		if (shader == null) return null;

		var isFunkinImpl = Std.isOfType(shader, FunkinShaderImpl);
		var funkinImpl:FunkinShaderImpl = isFunkinImpl ? cast shader : null;

		if (funkinImpl != null)
			funkinImpl.cancelTween(property);
		else
			cancelAnyShaderTween(shader, property);

		var from:Float = 0.0;
		var to:Float = 0.0;
		var duration:Float = 1.0;
		var easeFunc:Float->Float = null;
		var userOnComplete:FlxTween->Void = null;
		var tweenOpts:Dynamic = null;

		if (Std.isOfType(arg2, Float) || Std.isOfType(arg2, Int))
		{
			if (Std.isOfType(arg3, Float) || Std.isOfType(arg3, Int))
			{
				// (property, from, to, duration, ?easeOrOptions, ?onComplete)
				from = arg1;
				to = cast(arg2, Float);
				duration = cast(arg3, Float);

				if (Reflect.isFunction(arg4))
				{
					easeFunc = cast arg4;
					if (Reflect.isFunction(arg5)) userOnComplete = cast arg5;
				}
				else if (arg4 != null && Reflect.isObject(arg4))
				{
					tweenOpts = arg4;
				}
			}
			else
			{
				// (property, to, duration, ?easeOrOptions, ?onComplete)
				from = getShaderUniform(shader, property, 0.0);
				to = arg1;
				duration = cast(arg2, Float);

				if (Reflect.isFunction(arg3))
				{
					easeFunc = cast arg3;
					if (Reflect.isFunction(arg4)) userOnComplete = cast arg4;
				}
				else if (arg3 != null && Reflect.isObject(arg3))
				{
					tweenOpts = arg3;
				}
			}
		}
		else
		{
			// (property, to, ?easeOrOptions, ?onComplete) com duração default 1.0
			from = getShaderUniform(shader, property, 0.0);
			to = arg1;
			duration = 1.0;

			if (Reflect.isFunction(arg2))
			{
				easeFunc = cast arg2;
				if (Reflect.isFunction(arg3)) userOnComplete = cast arg3;
			}
			else if (arg2 != null && Reflect.isObject(arg2))
			{
				tweenOpts = arg2;
			}
		}

		if (tweenOpts != null && Reflect.hasField(tweenOpts, "from"))
		{
			var customFrom:Dynamic = Reflect.field(tweenOpts, "from");
			if (customFrom != null && (Std.isOfType(customFrom, Float) || Std.isOfType(customFrom, Int)))
				from = cast(customFrom, Float);
		}

		var cleanup = function() {
			if (funkinImpl != null)
			{
				funkinImpl.activeTweens.remove(property);
			}
			else
			{
				var m = _genericShaderTweens.get(shader);
				if (m != null) m.remove(property);
			}
		};

		if (tweenOpts == null)
		{
			tweenOpts = {
				ease: easeFunc,
				onComplete: function(t:FlxTween) {
					cleanup();
					if (userOnComplete != null) userOnComplete(t);
				}
			};
		}
		else
		{
			var origComplete:Dynamic = Reflect.field(tweenOpts, "onComplete");
			Reflect.setField(tweenOpts, "onComplete", function(t:FlxTween) {
				cleanup();
				if (origComplete != null && Reflect.isFunction(origComplete)) origComplete(t);
			});
			if (easeFunc != null && !Reflect.hasField(tweenOpts, "ease"))
			{
				Reflect.setField(tweenOpts, "ease", easeFunc);
			}
		}

		var twn = FlxTween.num(from, to, duration, tweenOpts, function(v:Float) {
			setShaderUniform(shader, property, v);
		});

		if (funkinImpl != null)
		{
			funkinImpl.activeTweens.set(property, twn);
		}
		else
		{
			var map = _genericShaderTweens.get(shader);
			if (map == null)
			{
				map = new Map<String, FlxTween>();
				_genericShaderTweens.set(shader, map);
			}
			map.set(property, twn);
		}

		return twn;
	}

	public function initUniformDefaults():Void
	{
		if (data != null)
		{
			if (Reflect.field(data, "hueMatrix") != null)
				Reflect.field(data, "hueMatrix").value = [1.0, 0.0, 0.0,  0.0, 1.0, 0.0,  0.0, 0.0, 1.0];
			if (Reflect.field(data, "saturationMatrix") != null)
				Reflect.field(data, "saturationMatrix").value = [1.0, 0.0, 0.0,  0.0, 1.0, 0.0,  0.0, 0.0, 1.0];
			if (Reflect.field(data, "contrast") != null)
				Reflect.field(data, "contrast").value = [1.0];
			if (Reflect.field(data, "brightness") != null)
				Reflect.field(data, "brightness").value = [0.0];
		}
	}

	public static function fromFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShaderImpl
	{
		var fragFile = getFilePath(fragmentPath, true);
		var vertFile = vertexPath != null ? getFilePath(vertexPath, false) : null;

		var fragContent = (fragFile != null && FileSystem.exists(fragFile)) ? File.getContent(fragFile) : null;
		var vertContent = (vertFile != null && FileSystem.exists(vertFile)) ? File.getContent(vertFile) : null;

		var shader = new FunkinShaderImpl(fragContent, vertContent, version);
		return shader;
	}

	public function loadShaderFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShaderImpl
	{
		var fragFile = getFilePath(fragmentPath, true);
		var vertFile = vertexPath != null ? getFilePath(vertexPath, false) : null;

		var fragContent = (fragFile != null && FileSystem.exists(fragFile)) ? File.getContent(fragFile) : null;
		var vertContent = (vertFile != null && FileSystem.exists(vertFile)) ? File.getContent(vertFile) : null;

		if (fragContent != null) glFragmentSource = fragContent;
		if (vertContent != null) glVertexSource = vertContent;
		
		@:privateAccess
		if (fragContent != null || vertContent != null) {
			__initGL();
			initUniformDefaults();
		}

		return this;
	}

	static function getFilePath(path:String, isFrag:Bool):String
	{
		if (path == null) return null;
		
		if (StringTools.startsWith(path, "assets/shaders/")) path = path.substr(15);
		else if (StringTools.startsWith(path, "shaders/")) path = path.substr(8);

		var ext = isFrag ? ".frag" : ".vert";
		if (!StringTools.endsWith(path, ext)) path += ext;
		
		#if sys
		if (backend.Mods.currentModDirectory != null && backend.Mods.currentModDirectory.length > 0)
		{
			var modPath = 'mods/' + backend.Mods.currentModDirectory + '/shaders/' + path;
			if (FileSystem.exists(modPath)) return modPath;
		}
		var globalModPath = 'mods/shaders/' + path;
		if (FileSystem.exists(globalModPath)) return globalModPath;

		var assetPath = 'assets/shaders/' + path;
		if (FileSystem.exists(assetPath)) return assetPath;
		#end

		return null;
	}
}
