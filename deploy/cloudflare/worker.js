// Edge proxy for draftmancer.greggg230.com.
//
// The Worker's custom domain gives us the DNS record without needing DNS-edit
// rights; every request (including Socket.IO's WebSocket upgrade, which fetch()
// passes through) is forwarded to wherever the server actually runs (ORIGIN).
// Moving hosts later only means changing ORIGIN in wrangler.jsonc.

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		const target = new URL(url.pathname + url.search, env.ORIGIN);
		const upstream = new Request(target, request);
		upstream.headers.set("X-Forwarded-Host", url.host);
		upstream.headers.set("X-Forwarded-Proto", "https");
		const ip = request.headers.get("CF-Connecting-IP");
		if (ip) upstream.headers.set("X-Forwarded-For", ip);
		try {
			return await fetch(upstream);
		} catch (err) {
			return new Response(`Draftmancer is offline right now (${err.message}).`, {
				status: 502,
				headers: { "Content-Type": "text/plain" },
			});
		}
	},
};
