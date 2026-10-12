package funkin.game.modchart;

enum abstract LogLevel(Int)
{
	var INFO = 0;
	var WARN = 1;
	var ERROR = 2;
}

class Logger
{
	public static inline function log(msg:Dynamic, ?level:LogLevel)
	{
		trace(msg);
	}
}
