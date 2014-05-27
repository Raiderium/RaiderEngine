module raider.engine.all;

public
{
	import raider.engine.animation.curve;

	import raider.engine.audio.listener;
	import raider.engine.audio.medium;
	import raider.engine.audio.music;
	import raider.engine.audio.sound;
	import raider.engine.audio.speaker;

	import raider.engine.game.entity;
	import raider.engine.game.factory;
	import raider.engine.game.game;
	import raider.engine.game.layer;
	import raider.engine.game.spawner;

	import raider.engine.physics.bod;
	import raider.engine.physics.collider;
	import raider.engine.physics.joint;
	import raider.engine.physics.shape;
	import raider.engine.physics.world;

	import raider.engine.network.networkable;

	import raider.engine.render.armature;
	import raider.engine.render.artist;
	import raider.engine.render.cable;
	import raider.engine.render.camera;
	import raider.engine.render.gl;
	import raider.engine.render.light;
	import raider.engine.render.material;
	import raider.engine.render.mesh;
	import raider.engine.render.model;
	import raider.engine.render.shader;
	import raider.engine.render.texture;
	import raider.engine.render.window;

	import raider.engine.tool.array;
	import raider.engine.tool.looper;
	import raider.engine.tool.packable;
	import raider.engine.tool.parallelism;
	import raider.engine.tool.reference;
	import raider.engine.tool.stream;

	import raider.math.all;
}

/*
 * RaiderEngine has no logo because that implies it is a program.
 * The engine is not the program; the game is the program.
 * The engine should be quiet. It has no right to be heard.
 * It is good for an engine to be simple, effective and powerful,
 * but it should also strive to be impossible to recognise.
 * To be so excellent at powering a unique experience that
 * it has no observable traits in the finished game.
 * Needing no recognition from its market's market.
 * 
 * RaiderEngine is an implementation detail.
 */