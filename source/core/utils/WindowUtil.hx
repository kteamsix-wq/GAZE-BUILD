package core.utils;

import lime.app.Application;
import lime.ui.Window;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;

/**
 * WindowUtil / WinUtil
 * 
 * Classe utilitária para manipulação dinâmica da janela da aplicação (Windows/Desktop).
 * Permite mover, escalar, alterar título (com efeito máquina de escrever e fake loading em loop),
 * alternar modo borderless e muito mais, tanto em código Haxe nativo quanto em scripts HScript.
 */
class WindowUtil
{
	/**
	 * Largura base original da janela (padrão: 1280).
	 */
	public static var defaultWidth:Int = 1280;

	/**
	 * Altura base original da janela (padrão: 720).
	 */
	public static var defaultHeight:Int = 720;

	/**
	 * Título base original da janela.
	 */
	public static var defaultTitle:String = "Friday Night Funkin': Gaze Engine";

	/**
	 * Tween ativo de movimentação da janela.
	 */
	public static var moveTween:FlxTween = null;

	/**
	 * Tween ativo de escala da janela.
	 */
	public static var scaleTween:FlxTween = null;

	/**
	 * Timer ativo de animação do título da janela.
	 */
	public static var titleTimer:FlxTimer = null;

	private static var _initialized:Bool = false;

	/**
	 * Inicializa e armazena os valores padrões da janela da aplicação.
	 */
	public static function init():Void
	{
		if (_initialized) return;
		var win = getWindow();
		if (win != null)
		{
			defaultWidth = win.width;
			defaultHeight = win.height;
			defaultTitle = win.title;
		}
		_initialized = true;
	}

	/**
	 * Obtém a instância da janela do Lime Application atual, de forma segura.
	 */
	public static inline function getWindow():Null<Window>
	{
		#if desktop
		if (Application.current != null)
		{
			if (!_initialized && Application.current.window != null)
			{
				defaultWidth = Application.current.window.width;
				defaultHeight = Application.current.window.height;
				defaultTitle = Application.current.window.title;
				_initialized = true;
			}
			return Application.current.window;
		}
		#end
		return null;
	}

	/**
	 * Move a janela para as coordenadas (x, y) na tela.
	 * 
	 * @param x Coordenada X na tela.
	 * @param y Coordenada Y na tela.
	 * @param tween Se true, interpola o movimento suavemente.
	 * @param ease Easing da interpolação (padrão: FlxEase.linear). Aceita FlxEase function, String ("cubeOut", etc.) ou Float (duração).
	 * @param duration Duração da interpolação em segundos (padrão: 1.0s).
	 */
	public static function winMove(x:Float, y:Float, ?tween:Bool = false, ?ease:Dynamic = null, ?duration:Dynamic = null):Void
	{
		var win = getWindow();
		if (win == null) return;

		// Cancelar tween de movimento anterior se houver
		if (moveTween != null)
		{
			moveTween.cancel();
			moveTween.destroy();
			moveTween = null;
		}

		var targetX:Int = Math.round(x);
		var targetY:Int = Math.round(y);

		if (!tween)
		{
			win.move(targetX, targetY);
			return;
		}

		// Resolução flexível de argumentos
		var actualEase:Dynamic = FlxEase.linear;
		var actualDuration:Float = 1.0;

		if (Std.isOfType(ease, Float) || Std.isOfType(ease, Int))
		{
			actualDuration = cast(ease, Float);
			if (duration != null) actualEase = duration;
		}
		else
		{
			if (ease != null) actualEase = ease;
			if (duration != null && (Std.isOfType(duration, Float) || Std.isOfType(duration, Int)))
				actualDuration = cast(duration, Float);
		}

		if (actualDuration <= 0) actualDuration = 1.0;

		var startX:Float = win.x;
		var startY:Float = win.y;
		var easeFunc = resolveEase(actualEase);

		moveTween = FlxTween.num(0.0, 1.0, actualDuration, {
			ease: easeFunc,
			onComplete: function(_) {
				moveTween = null;
				if (win != null) win.move(targetX, targetY);
			}
		}, function(v:Float) {
			if (win != null) {
				win.move(Math.round(startX + (targetX - startX) * v), Math.round(startY + (targetY - startY) * v));
			}
		});
	}

	/**
	 * Modifica a escala da janela.
	 * 
	 * @param scale Fator de escala multiplicador (ex: 1.0 = normal, 0.5 = metade, 1.5 = 1.5x).
	 * @param tween Se true, interpola a escala suavemente.
	 * @param ease Easing da interpolação (padrão: FlxEase.linear).
	 * @param res Se true (padrão), calcula a escala em relação à resolução nativa (1280x720) e mantém a janela centralizada.
	 *            Se false, calcula a escala em relação ao tamanho atual da janela, mantendo o canto superior esquerdo ancorado.
	 * @param duration Duração da interpolação em segundos (padrão: 1.0s).
	 */
	public static function winScale(scale:Float, ?tween:Bool = false, ?ease:Dynamic = null, ?res:Dynamic = true, ?duration:Dynamic = null):Void
	{
		var win = getWindow();
		if (win == null) return;

		// Cancelar tween de escala anterior se houver
		if (scaleTween != null)
		{
			scaleTween.cancel();
			scaleTween.destroy();
			scaleTween = null;
		}

		var actualRes:Bool = true;
		var actualEase:Dynamic = FlxEase.linear;
		var actualDuration:Float = 1.0;

		// Resolução flexível de argumentos
		if (Std.isOfType(ease, Float) || Std.isOfType(ease, Int))
		{
			actualDuration = cast(ease, Float);
			if (res != null && !Std.isOfType(res, Bool))
				actualEase = res;
			if (duration != null && Std.isOfType(duration, Bool))
				actualRes = cast duration;
		}
		else
		{
			if (ease != null) actualEase = ease;
			if (Std.isOfType(res, Bool))
			{
				actualRes = cast res;
			}
			else if (Std.isOfType(res, Float) || Std.isOfType(res, Int))
			{
				actualDuration = cast(res, Float);
			}

			if (duration != null)
			{
				if (Std.isOfType(duration, Float) || Std.isOfType(duration, Int))
					actualDuration = cast(duration, Float);
				else if (Std.isOfType(duration, Bool))
					actualRes = cast duration;
			}
		}

		if (actualDuration <= 0) actualDuration = 1.0;

		var targetW:Int;
		var targetH:Int;

		if (actualRes)
		{
			targetW = Math.round(defaultWidth * scale);
			targetH = Math.round(defaultHeight * scale);
		}
		else
		{
			targetW = Math.round(win.width * scale);
			targetH = Math.round(win.height * scale);
		}

		// Limites mínimos de segurança para a janela não sumir
		if (targetW < 160) targetW = 160;
		if (targetH < 90) targetH = 90;

		var startW:Float = win.width;
		var startH:Float = win.height;
		var startX:Float = win.x;
		var startY:Float = win.y;

		// Mantém o centro da janela no mesmo ponto da tela se res for true
		var targetX:Float = actualRes ? (startX + (startW - targetW) / 2.0) : startX;
		var targetY:Float = actualRes ? (startY + (startH - targetH) / 2.0) : startY;

		if (!tween)
		{
			if (actualRes)
				win.move(Math.round(targetX), Math.round(targetY));
			win.resize(targetW, targetH);
			return;
		}

		var easeFunc = resolveEase(actualEase);

		scaleTween = FlxTween.num(0.0, 1.0, actualDuration, {
			ease: easeFunc,
			onComplete: function(_) {
				scaleTween = null;
				if (win != null)
				{
					if (actualRes)
						win.move(Math.round(targetX), Math.round(targetY));
					win.resize(targetW, targetH);
				}
			}
		}, function(v:Float) {
			if (win != null)
			{
				var curW = Math.round(startW + (targetW - startW) * v);
				var curH = Math.round(startH + (targetH - startH) * v);
				if (actualRes)
				{
					var curX = Math.round(startX + (targetX - startX) * v);
					var curY = Math.round(startY + (targetY - startY) * v);
					win.move(curX, curY);
				}
				win.resize(curW, curH);
			}
		});
	}

	/**
	 * Modifica o título da janela em tempo real.
	 * 
	 * @param newName O novo texto para o título da janela.
	 * @param digitalized Se true, simula uma pessoa digitando letra por letra (efeito máquina de escrever).
	 * @param fakeLoading Se true, exibe reticências animadas em loop ("newName", "newName.", "newName..", "newName...") sem digitação letra por letra.
	 *                    Se digitalized e fakeLoading forem ambos true, primeiro digita o texto e em seguida inicia o loop de reticências.
	 */
	public static function winName(newName:String, ?digitalized:Bool = false, ?fakeLoading:Bool = false):Void
	{
		var win = getWindow();
		if (win == null) return;

		// Interrompe qualquer animação de título anterior
		stopTitleAnimation();

		var baseText:String = (newName != null) ? newName : defaultTitle;

		// Caso 1: Troca direta e instantânea
		if (!digitalized && !fakeLoading)
		{
			win.title = baseText;
			return;
		}

		// Caso 2: Apenas Fake Loading (sem digitalizar letra por letra, apenas 3 pontos em loop)
		if (!digitalized && fakeLoading)
		{
			win.title = baseText;
			startFakeLoading(baseText);
			return;
		}

		// Caso 3: Digitalized (digitação letra por letra, com opção de encadear fake loading ao final)
		if (digitalized)
		{
			var totalLength:Int = baseText.length;
			if (totalLength == 0)
			{
				win.title = "";
				if (fakeLoading)
					startFakeLoading(baseText);
				return;
			}

			win.title = "";
			var currentChars:Int = 0;

			titleTimer = new FlxTimer().start(0.05, function(tmr:FlxTimer)
			{
				currentChars++;
				var currentWin = getWindow();
				if (currentWin != null)
				{
					currentWin.title = baseText.substr(0, currentChars);
				}

				if (currentChars >= totalLength)
				{
					tmr.cancel();
					tmr.destroy();
					titleTimer = null;

					if (fakeLoading)
					{
						startFakeLoading(baseText);
					}
				}
			}, 0);
		}
	}

	/**
	 * Inicia o loop de fake loading exibindo "..." em ciclo contínuo.
	 */
	private static function startFakeLoading(baseText:String):Void
	{
		var win = getWindow();
		if (win == null) return;

		stopTitleAnimation();

		var dotCount:Int = 0;
		win.title = baseText;

		titleTimer = new FlxTimer().start(0.4, function(tmr:FlxTimer)
		{
			dotCount = (dotCount + 1) % 4; // Ciclos: 1 -> 2 -> 3 -> 0
			var dots:String = "";
			for (i in 0...dotCount)
			{
				dots += ".";
			}

			var currentWin = getWindow();
			if (currentWin != null)
			{
				currentWin.title = baseText + dots;
			}
		}, 0); // Loop infinito até ser cancelado
	}

	/**
	 * Para qualquer timer ativo de animação de título (digitalized ou fakeLoading).
	 */
	public static function stopTitleAnimation():Void
	{
		if (titleTimer != null)
		{
			titleTimer.cancel();
			titleTimer.destroy();
			titleTimer = null;
		}
	}

	/**
	 * Propriedade booleana para ativar ou desativar o modo borderless (sem bordas) da janela.
	 */
	public static var borderless(get, set):Bool;

	private static function get_borderless():Bool
	{
		var win = getWindow();
		return win != null ? win.borderless : false;
	}

	private static function set_borderless(value:Bool):Bool
	{
		var win = getWindow();
		if (win != null)
		{
			win.borderless = value;
		}
		return value;
	}

	/**
	 * Atalho de função para definir o modo borderless.
	 */
	public static function winBorderless(enable:Bool):Bool
	{
		borderless = enable;
		return borderless;
	}

	/**
	 * Centraliza a janela no monitor/display atual.
	 */
	public static function winCenter():Void
	{
		var win = getWindow();
		if (win == null) return;

		var display = win.display;
		if (display != null && display.bounds != null)
		{
			var screenW:Int = Math.round(display.bounds.width);
			var screenH:Int = Math.round(display.bounds.height);
			var screenX:Int = Math.round(display.bounds.x);
			var screenY:Int = Math.round(display.bounds.y);
			var targetX:Int = screenX + Std.int((screenW - win.width) / 2);
			var targetY:Int = screenY + Std.int((screenH - win.height) / 2);
			win.move(targetX, targetY);
		}
	}

	/**
	 * Cancela todos os tweens de janela ativos (movimento e escala).
	 */
	public static function stopTweens():Void
	{
		if (moveTween != null)
		{
			moveTween.cancel();
			moveTween.destroy();
			moveTween = null;
		}
		if (scaleTween != null)
		{
			scaleTween.cancel();
			scaleTween.destroy();
			scaleTween = null;
		}
	}

	/**
	 * Restaura a janela para o estado padrão (tamanho 1280x720, centralizada, com bordas normais e título padrão).
	 */
	public static function winReset(?revertTitle:Bool = true):Void
	{
		stopTweens();
		stopTitleAnimation();

		var win = getWindow();
		if (win != null)
		{
			win.borderless = false;
			win.resize(defaultWidth, defaultHeight);
			winCenter();
			if (revertTitle)
				win.title = defaultTitle;
		}
	}

	// ==========================================
	// Getters & Setters de conveniência
	// ==========================================

	public static var x(get, set):Int;
	private static inline function get_x():Int
	{
		var win = getWindow();
		return win != null ? win.x : 0;
	}
	private static inline function set_x(val:Int):Int
	{
		var win = getWindow();
		if (win != null) win.x = val;
		return val;
	}

	public static var y(get, set):Int;
	private static inline function get_y():Int
	{
		var win = getWindow();
		return win != null ? win.y : 0;
	}
	private static inline function set_y(val:Int):Int
	{
		var win = getWindow();
		if (win != null) win.y = val;
		return val;
	}

	public static var width(get, set):Int;
	private static inline function get_width():Int
	{
		var win = getWindow();
		return win != null ? win.width : defaultWidth;
	}
	private static inline function set_width(val:Int):Int
	{
		var win = getWindow();
		if (win != null) win.width = val;
		return val;
	}

	public static var height(get, set):Int;
	private static inline function get_height():Int
	{
		var win = getWindow();
		return win != null ? win.height : defaultHeight;
	}
	private static inline function set_height(val:Int):Int
	{
		var win = getWindow();
		if (win != null) win.height = val;
		return val;
	}

	public static var title(get, set):String;
	private static inline function get_title():String
	{
		var win = getWindow();
		return win != null ? win.title : defaultTitle;
	}
	private static inline function set_title(val:String):String
	{
		winName(val, false, false);
		return val;
	}

	public static var scale(get, never):Float;
	private static inline function get_scale():Float
	{
		var win = getWindow();
		if (win != null && defaultWidth > 0)
			return win.width / defaultWidth;
		return 1.0;
	}

	/**
	 * Converte nomes de ease em strings ou valores dinâmicos para a EaseFunction do FlxEase.
	 */
	public static function resolveEase(ease:Dynamic):EaseFunction
	{
		if (ease == null)
			return FlxEase.linear;

		if (Reflect.isFunction(ease))
			return cast ease;

		if (Std.isOfType(ease, String))
		{
			var easeStr:String = StringTools.trim(Std.string(ease)).toLowerCase();
			if (easeStr.indexOf(".") != -1)
			{
				var parts = easeStr.split(".");
				easeStr = parts[parts.length - 1];
			}

			switch (easeStr)
			{
				case "linear": return FlxEase.linear;
				case "quadin": return FlxEase.quadIn;
				case "quadout": return FlxEase.quadOut;
				case "quadinout": return FlxEase.quadInOut;
				case "cubein": return FlxEase.cubeIn;
				case "cubeout": return FlxEase.cubeOut;
				case "cubeinout": return FlxEase.cubeInOut;
				case "quartin": return FlxEase.quartIn;
				case "quartout": return FlxEase.quartOut;
				case "quartinout": return FlxEase.quartInOut;
				case "quintin": return FlxEase.quintIn;
				case "quintout": return FlxEase.quintOut;
				case "quintinout": return FlxEase.quintInOut;
				case "sinein": return FlxEase.sineIn;
				case "sineout": return FlxEase.sineOut;
				case "sineinout": return FlxEase.sineInOut;
				case "bouncein": return FlxEase.bounceIn;
				case "bounceout": return FlxEase.bounceOut;
				case "bounceinout": return FlxEase.bounceInOut;
				case "circin": return FlxEase.circIn;
				case "circout": return FlxEase.circOut;
				case "circinout": return FlxEase.circInOut;
				case "expoin": return FlxEase.expoIn;
				case "expoout": return FlxEase.expoOut;
				case "expoinout": return FlxEase.expoInOut;
				case "backin": return FlxEase.backIn;
				case "backout": return FlxEase.backOut;
				case "backinout": return FlxEase.backInOut;
				case "elasticin": return FlxEase.elasticIn;
				case "elasticout": return FlxEase.elasticOut;
				case "elasticinout": return FlxEase.elasticInOut;
				case "smoothstepin": return FlxEase.smoothStepIn;
				case "smoothstepout": return FlxEase.smoothStepOut;
				case "smoothstepinout": return FlxEase.smoothStepInOut;
				case "smootherstepin": return FlxEase.smootherStepIn;
				case "smootherstepout": return FlxEase.smootherStepOut;
				case "smootherstepinout": return FlxEase.smootherStepInOut;
				default:
					var field = Reflect.field(FlxEase, Std.string(ease));
					if (field != null && Reflect.isFunction(field))
						return cast field;
					return FlxEase.linear;
			}
		}

		return FlxEase.linear;
	}
}

/**
 * Alias WinUtil para facilidade de digitação e compatibilidade total.
 */
typedef WinUtil = WindowUtil;
