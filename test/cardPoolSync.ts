import { describe, it } from "mocha";
import { expect } from "chai";

import { diffCardPools } from "../src/CardPoolSync.js";
import { UniqueCard } from "../src/CardTypes.js";

const card = (uniqueID: number) => ({ uniqueID, name: `Card ${uniqueID}` }) as UniqueCard;
const ids = (cards: UniqueCard[]) => cards.map((c) => c.uniqueID);

describe("Card pool sync", function () {
	it("finds nothing when both copies hold the same cards, wherever they sit", function () {
		const diff = diffCardPools(
			{ main: [card(1), card(2)], side: [card(3)] },
			{ main: [card(1)], side: [card(2), card(3)] }
		);
		expect(ids(diff.missing.main)).to.be.empty;
		expect(ids(diff.missing.side)).to.be.empty;
		expect(ids(diff.extra)).to.be.empty;
	});

	it("reports picks the client never added, keeping the server's main/side placement", function () {
		const diff = diffCardPools({ main: [card(1)], side: [] }, { main: [card(1), card(2)], side: [card(3)] });
		expect(ids(diff.missing.main)).to.deep.equal([2]);
		expect(ids(diff.missing.side)).to.deep.equal([3]);
		expect(ids(diff.extra)).to.be.empty;
	});

	it("reports cards the client shows but the server never gave the player", function () {
		const diff = diffCardPools({ main: [card(1), card(4)], side: [card(5)] }, { main: [card(1)], side: [] });
		expect(ids(diff.missing.main)).to.be.empty;
		expect(ids(diff.extra)).to.deep.equal([4, 5]);
	});
});
