module raider.engine.app;

import raider.engine.game;
import raider.tools.reference;

/* This is the main() for any game.
 * To start creating a game, make an entity called 'Main'.
 * It will be automatically instanced.
 */
version(unittest)
{

}
else
{
	void main()
	{
		R!Game game = New!Game();
		game.run;
	}
}