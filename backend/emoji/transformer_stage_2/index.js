const fs = require("fs");
const csv = require("csv-parser");

const data = [];
fs.createReadStream("../emoji_transformed_stage_1.csv")
	.pipe(csv())
	.on("data", (line) => data.push(line))
	.on("end", () => {
		transform();
		transformForDesc();
	});

function transform() {
	let out = "";
	for(let emoji of data) {
		const allCodes = JSON.parse(emoji.all_codes);
		out += `${emoji.code}`;
		for(let code of Object.values(allCodes)) {
			const replaced = code.replace(/:/gi, "");
			out += `,${replaced}`;
		}
		out += "\n";
	}
	fs.writeFileSync("../emoji_transformed_stage_2.csv", out);
}

async function transformForDesc() {
	const allDesc = [];
	const codes = [];
	for (const emoji of data) {
		allDesc.push(emoji.cleaned_description);
		codes.push(emoji.code);
	}

	fs.writeFileSync("../emoji_index.json", JSON.stringify(codes));

	return;

	const allData = [];
	for (let i = 0; i < allDesc.length; i += 50) {
		const res = await fetch("https://my-emoji.sidachen2003.workers.dev", {
			headers: {
				"Content-Type": "application/json",
			},
			method: "POST",
			body: JSON.stringify(allDesc.slice(i, i + 50)),
		})
		const res2 = res.clone();
		try {
			const data = await res.json();
			allData.push(...data.data);
			console.log(i, "completed");
		} catch (e) {
			console.log(i, "failed with", res.status);
			console.log(allDesc.slice(i, i + 50));
			// console.error(e);
			// console.log(await res2.text());
		}
		await new Promise((resolve) => setTimeout(resolve, 1000));
	}
	fs.writeFileSync("../emoji_desc_embeddings.json", JSON.stringify(allData));
}
