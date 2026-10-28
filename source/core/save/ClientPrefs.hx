package core.save;
import core.base.Init;

class ClientPrefs
{
	public static var downScroll(get, never):Bool;
	inline static function get_downScroll():Bool return Init.trueSettings.get('Downscroll');

	public static var lowQuality:Bool = false;
	public static var quants:Bool = false;
	public static var underlayOpacity:Float = 0;
}
