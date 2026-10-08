import type { UniqueCard } from "./CardTypes.js";

export type PlayerCardPool = { main: UniqueCard[]; side: UniqueCard[] };

// Compares a client's copy of a player's card pool with the server's authoritative one.
// Clients add picks to their pool before the server confirms them and only resync on reconnection,
// so the two can drift apart (e.g. a pick racing a reconnection).
export function diffCardPools(local: PlayerCardPool, server: PlayerCardPool) {
	const localIDs = new Set([...local.main, ...local.side].map((c) => c.uniqueID));
	const serverIDs = new Set([...server.main, ...server.side].map((c) => c.uniqueID));
	return {
		// Recorded by the server but absent from the client, with the server's main/side placement.
		missing: {
			main: server.main.filter((c) => !localIDs.has(c.uniqueID)),
			side: server.side.filter((c) => !localIDs.has(c.uniqueID)),
		},
		// Shown by the client but never given to the player by the server.
		extra: [...local.main, ...local.side].filter((c) => !serverIDs.has(c.uniqueID)),
	};
}
