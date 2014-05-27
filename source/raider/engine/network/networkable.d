module raider.engine.network.networkable;

interface Networkable
{

}

/*
Here's a story about a layer above UDP called 
'Small Town Messenger', or STM, or perhaps 'Hayate'.

In this story, there are Towns (peers) containing Peeps 
(networked entities). One town has a Post Office (server). 
All the towns strive to be identical. Peeps may be clones, 
in which case they have an Owner, the original peep. 

Owners send Letters to their clones via the post office. 
The clones use these letters to try and imitate their
owners. If a clone tries to send a letter, it is ignored.

The post office is very powerful; it rules the entire planet.
Clones living there aren't allowed to send letters, though 
they might as well be - instead, they can send Decrees, 
messages of great import that are guaranteed to be delivered 
and read in a particular order, if one is specified. Fancy.

The most common Decree orders the removal or arrival of a peep 
and clones. The second-most common demands that a clone and 
owner swap bodies. (Do you see why they might as well be able 
to send letters?)

The post office also tightly restricts the use of magic to its 
own town, and punishes lawbreakers in other towns. If a peep 
appears to cast a spell or resist a decree, its town will be 
judged by wizards and possibly expurgated from the annals of 
time and space (dishonorably disconnected).

If a clone becomes a significant citizen (perhaps by approaching 
owners in a town), the owner may send very small messages to 
it called Notes, bypassing the post office in favour of a hired 
messenger (peer-to-peer connection), in order to maintain its 
appearance better. Notes do not contain anything of great 
significance; just little hints to the clone on how to look like 
its owner.

The messengers that carry Notes, Letters and Decrees carry many 
on each trip between towns. Should they fall victim to bandits, 
all is lost; but Decrees will be redelivered until a returning 
messenger confirms delivery, or the post office decides the town 
doesn't exist anymore.
 */