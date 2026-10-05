package backend;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

import backend.CoolUtil;
import backend.Timings;
import funkin.states.PlayState;
import Paths;
import Utils;
import Init;

class ClassHUD extends FlxTypedGroup<FlxBasic>
{
	// UI Elements
	public var scoreBar:FlxText;
	public var centerMark:FlxText;
	public var autoplayMark:FlxText;

	public var healthBarBG:FlxSprite;
	public var healthBar:FlxBar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	// Variables
	var displayedScore:Float = 0;
	var autoplaySine:Float = 0;
	
	// Settings / Cache
	var isDownscroll:Bool = Init.trueSettings.get('Downscroll');

	final divider:String = " • ";

	public function new()
	{
		super();
		
		setupHealthBar();
		setupIcons();
		setupTextElements();

		updateScoreText();
	}

	function setupHealthBar()
	{
		healthBarBG = new FlxSprite(0, isDownscroll ? FlxG.height * 0.11 : FlxG.height * 0.89);
		healthBarBG.loadGraphic(Paths.image('UI/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8));
		healthBar.scrollFactor.set();
		healthBar.setRange(0, 2);
		healthBar.value = PlayState.health;

		var dadColors = PlayState.dadOpponent.healthColorArray;
		var bfColors = PlayState.boyfriend.healthColorArray;
		
		var dadColor:FlxColor = FlxColor.fromRGB(dadColors[0], dadColors[1], dadColors[2]);
		var bfColor:FlxColor = FlxColor.fromRGB(bfColors[0], bfColors[1], bfColors[2]);
		
		healthBar.createFilledBar(dadColor, bfColor);
		add(healthBar);
	}

	function setupIcons()
	{
		iconP1 = new HealthIcon(PlayState.boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		add(iconP1);

		iconP2 = new HealthIcon(PlayState.dadOpponent.healthIcon, false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		add(iconP2);
	}

	function setupTextElements()
	{
		var font:String = Paths.font('vcr.ttf');
		
		scoreBar = new FlxText(490, isDownscroll ? 29 : 680, 0, "");
		scoreBar.setFormat(font, 18, FlxColor.WHITE);
		scoreBar.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		scoreBar.antialiasing = true;
		add(scoreBar);

		var infoDisplay:String = CoolUtil.dashToSpace(PlayState.SONG.song);
		centerMark = new FlxText(0, isDownscroll ? FlxG.height - 40 : 10, 0, '- $infoDisplay -');
		centerMark.setFormat(font, 24, FlxColor.WHITE);
		centerMark.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		centerMark.screenCenter(X);
		centerMark.antialiasing = true;
		add(centerMark);

		autoplayMark = new FlxText(-5, centerMark.y + (isDownscroll ? -60 : 60), FlxG.width - 800, '[BOTPLAY]\n', 32);
		autoplayMark.setFormat(font, 32, FlxColor.WHITE, CENTER);
		autoplayMark.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		autoplayMark.screenCenter(X);
		autoplayMark.visible = PlayState.boyfriendStrums.autoplay;

		if (Init.trueSettings.get('Centered Notefield'))
			autoplayMark.y += isDownscroll ? -125 : 125;

		add(autoplayMark);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		updateHealthBar(elapsed);
		updateScoreLerp(elapsed);

		if (autoplayMark.visible)
		{
			autoplaySine += 180 * (elapsed / 4);
			autoplayMark.alpha = 1 - Math.sin((Math.PI * autoplaySine) / 80);
		}
	}

	function updateHealthBar(elapsed:Float)
	{
		healthBar.value = FlxMath.lerp(healthBar.value, PlayState.health, Math.exp(-elapsed * 15));
		healthBar.updateBar(); // Force visual update just in case

		var iconOffset:Int = 26;
		var percentMath:Float = FlxMath.remapToRange(healthBar.value, 0, 2, 100, 0) * 0.01;
		var iconPos:Float = healthBar.x + (healthBar.width * percentMath);

		iconP1.x = iconPos - iconOffset;
		iconP2.x = iconPos - (iconP2.width - iconOffset);
		
		var iconP1Health = FlxMath.remapToRange(healthBar.value, 0, 2, 0, 100);
		iconP1.updateAnim(iconP1Health);
		iconP2.updateAnim(100 - iconP1Health);

		// V-Slice icon bop lerp
		var mult1:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9));
		iconP1.scale.set(mult1, mult1);
		iconP1.updateHitbox();

		var mult2:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9));
		iconP2.scale.set(mult2, mult2);
		iconP2.updateHitbox();
	}

	function updateScoreLerp(elapsed:Float)
	{
		if (Math.abs(displayedScore - PlayState.songScore) > 0.1) 
		{
			displayedScore = FlxMath.lerp(displayedScore, PlayState.songScore, elapsed * 15);
			if (Math.abs(displayedScore - PlayState.songScore) < 0.1) 
				displayedScore = PlayState.songScore;
			
			updateScoreText();
		}
	}

	public function beatHit(beat:Int)
	{
		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);
		iconP1.updateHitbox();
		iconP2.updateHitbox();
	}

	private function formatScore(score:Int):String 
	{
		var str = Std.string(score);
		var formatted = "";
		var count = 0;
		for(i in 0...str.length) {
			var idx = str.length - 1 - i;
			formatted = str.charAt(idx) + formatted;
			count++;
			if(count == 3 && idx > 0 && str.charAt(idx - 1) != "-") {
				formatted = "," + formatted;
				count = 0;
			}
		}
		return formatted;
	}

	public function updateScoreText()
	{
		var rankDisplay = Timings.returnScoreRating().toUpperCase();
		if (rankDisplay == "" || rankDisplay == "?" || rankDisplay == null) 
			rankDisplay = "N/A";

		scoreBar.text = 'Score: ${formatScore(Math.round(displayedScore))}$divider Misses: ${PlayState.misses}$divider Rank: $rankDisplay';
		scoreBar.screenCenter(X);

		PlayState.detailsSub = scoreBar.text;
	}
}
