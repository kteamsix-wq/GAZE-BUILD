package core.system;

#if cpp
import cpp.Pointer;
import cpp.RawConstPointer;
import cpp.RawPointer;
import cpp.Stdlib;
import cpp.UInt8;
import webp._internal.Decode;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.io.Bytes;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.PixelFormat;
import lime.utils.UInt8Array;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

/**
 * High-performance WebP loader and decoder for Gaze Engine.
 *
 * Provides native direct-buffer decoding via libwebp (hxWebP) on C++ platforms
 * to prevent memory leaks and byte-by-byte copying overhead.
 * Handles HTML5 targets natively through the browser's asset pipeline.
 */
class WebPUtil
{
	/**
	 * Checks whether a given path or filename has a `.webp` extension.
	 */
	inline public static function isWebP(path:String):Bool
	{
		if (path == null) return false;
		return path.toLowerCase().endsWith('.webp');
	}

	/**
	 * Loads an OpenFL BitmapData from a WebP file path or OpenFL asset key.
	 */
	public static function getBitmapData(path:String):BitmapData
	{
		if (path == null || path.length == 0) return null;

		#if (js && html5)
		if (OpenFlAssets.exists(path, IMAGE))
			return OpenFlAssets.getBitmapData(path, false);
		var img = Image.fromFile(path);
		return img != null ? BitmapData.fromImage(img) : null;
		#else
		#if sys
		if (FileSystem.exists(path))
		{
			try
			{
				var bytes = File.getBytes(path);
				if (bytes != null && bytes.length > 0)
				{
					var bmp = getBitmapDataFromBytes(bytes);
					if (bmp != null) return bmp;
				}
			}
			catch (e:Dynamic)
			{
				flixel.FlxG.log.warn('WebPUtil: Failed to read file bytes from $path: $e');
			}
		}
		#end

		var normalized = path.replace('\\', '/');
		if (OpenFlAssets.exists(normalized, IMAGE) || OpenFlAssets.exists(normalized, BINARY) || OpenFlAssets.exists(normalized))
		{
			try
			{
				var bytes = OpenFlAssets.getBytes(normalized);
				if (bytes != null && bytes.length > 0)
				{
					var bmp = getBitmapDataFromBytes(bytes);
					if (bmp != null) return bmp;
				}
			}
			catch (e:Dynamic)
			{
				flixel.FlxG.log.warn('WebPUtil: Failed to read asset bytes from $path: $e');
			}
		}

		#if cpp
		// Fallback to hxWebP default loader
		try
		{
			var bmp = webp.WebP.getBitmapData(path);
			if (bmp != null) return bmp;
		}
		catch (e:Dynamic)
		{
			flixel.FlxG.log.warn('WebPUtil: Fallback webp.WebP.getBitmapData failed for $path: $e');
		}
		#end

		return null;
		#end
	}

	/**
	 * Decodes WebP bytes directly into an OpenFL BitmapData instance.
	 * Decodes directly into destination memory with zero intermediate allocations or leaks.
	 */
	@:analyzer(no_const_propagation, no_local_dce, no_fusion)
	public static function getBitmapDataFromBytes(bytes:Bytes):BitmapData
	{
		if (bytes == null || bytes.length == 0) return null;

		#if (js && html5)
		var image = Image.fromBytes(bytes);
		return image != null ? BitmapData.fromImage(image) : null;
		#elseif cpp
		try
		{
			var bytesData = bytes.getData();
			var rawBytes:RawConstPointer<UInt8> = cast Pointer.ofArray(bytesData).raw;

			var widthPtr:Pointer<Int> = Stdlib.malloc(Stdlib.sizeof(Int));
			var heightPtr:Pointer<Int> = Stdlib.malloc(Stdlib.sizeof(Int));
			var infoRes:Int = Decode.WebPGetInfo(rawBytes, bytes.length, widthPtr.raw, heightPtr.raw);
			var w:Int = (infoRes != 0) ? widthPtr.value : 0;
			var h:Int = (infoRes != 0) ? heightPtr.value : 0;
			Stdlib.free(widthPtr);
			Stdlib.free(heightPtr);

			if (infoRes == 0 || w <= 0 || h <= 0)
			{
				flixel.FlxG.log.warn('WebPUtil: Invalid WebP header or dimensions ($w x $h), trying hxWebP fallback...');
				return webp.WebP.getBitmapDataFromBytes(bytes);
			}

			var stride:Int = w * 4;
			var bufferSize:Int = stride * h;
			var decodedBytes:Bytes = Bytes.alloc(bufferSize);
			var outRaw:RawPointer<UInt8> = cast Pointer.ofArray(decodedBytes.getData()).raw;

			#if windows
			var decodedPtr = Decode.WebPDecodeBGRAInto(rawBytes, bytes.length, outRaw, bufferSize, stride);
			#else
			var decodedPtr = Decode.WebPDecodeRGBAInto(rawBytes, bytes.length, outRaw, bufferSize, stride);
			#end

			if (decodedPtr == null)
			{
				flixel.FlxG.log.warn('WebPUtil: WebPDecodeBGRAInto returned null, trying hxWebP fallback...');
				return webp.WebP.getBitmapDataFromBytes(bytes);
			}

			var uint8Array:UInt8Array = UInt8Array.fromBytes(decodedBytes);
			var imageBuffer:ImageBuffer = new ImageBuffer(uint8Array, w, h, 32, #if windows BGRA32 #else RGBA32 #end);
			var image:Image = new Image(imageBuffer);
			var bitmap:BitmapData = BitmapData.fromImage(image, true);
			if (bitmap != null)
				return bitmap;

			return webp.WebP.getBitmapDataFromBytes(bytes);
		}
		catch (e:Dynamic)
		{
			flixel.FlxG.log.warn('WebPUtil: Native direct decode failed: $e. Falling back to hxWebP...');
			try
			{
				return webp.WebP.getBitmapDataFromBytes(bytes);
			}
			catch (err:Dynamic)
			{
				flixel.FlxG.log.warn('WebPUtil: Fallback decode also failed: $err');
			}
		}
		return null;
		#else
		return null;
		#end
	}
}
