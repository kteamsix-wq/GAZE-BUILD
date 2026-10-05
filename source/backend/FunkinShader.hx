package backend;

import flixel.addons.display.FlxRuntimeShader;
import openfl.display.ShaderParameter;
import openfl.display.ShaderInput;
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
		if (this.data.exists(name))
		{
			var prop = Reflect.field(this.data, name);
			if (Std.isOfType(value, Array)) {
				prop.value = value;
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
		if (this.data.exists(name))
		{
			var prop = Reflect.field(this.data, name);
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
	public function new(?fragmentSource:String, ?vertexSource:String, ?version:String)
	{
		super(fragmentSource, vertexSource);
	}

	public static function fromFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShaderImpl
	{
		var shader = new FunkinShaderImpl();
		shader.loadShaderFile(fragmentPath, vertexPath, version);
		return shader;
	}

	public function loadShaderFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShaderImpl
	{
		if (vertexPath == null)
		{
			var idx = fragmentPath.lastIndexOf(".");
			if (idx == -1) vertexPath = fragmentPath;
			else vertexPath = fragmentPath.substr(0, idx);
		}

		var fragFile = getFilePath(fragmentPath, true);
		var vertFile = getFilePath(vertexPath, false);

		var fragContent = (fragFile != null && FileSystem.exists(fragFile)) ? File.getContent(fragFile) : null;
		var vertContent = (vertFile != null && FileSystem.exists(vertFile)) ? File.getContent(vertFile) : null;

		if (fragContent != null) glFragmentSource = fragContent;
		if (vertContent != null) glVertexSource = vertContent;
		
		@:privateAccess
		if (fragContent != null || vertContent != null) {
			__initGL();
		}

		return this;
	}

	static function getFilePath(path:String, isFrag:Bool):String
	{
		if (path == null) return null;
		
		var ext = isFrag ? ".frag" : ".vert";
		if (!StringTools.endsWith(path, ext)) path += ext;
		
		var fullPath = Paths.getPath('shaders/$path', TEXT);
		if (FileSystem.exists(fullPath)) return fullPath;
		
		return path; // Fallback caso não seja encontrado no Paths
	}
}
