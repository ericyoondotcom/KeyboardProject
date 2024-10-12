const fs = require("fs");
const csv = require("csv-parser");

const data = [];
let out = "";
fs.createReadStream("../emoji_transformed_stage_1.csv")
	.pipe(csv())
	.on("data", (line) => data.push(line))
	.on("end", () => {
		transform();
	});

function transform() {
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
