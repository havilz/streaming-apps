import { gotScraping } from "got-scraping";

const BASE_URL = "https://z2.idlixku.com";
const headers = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

async function main() {
  // Test 1: movies pagination item
  try {
    const res = await gotScraping({
      url: `${BASE_URL}/api/movies?page=1`,
      headers,
      useHeaderGenerator: false,
    });
    const data = JSON.parse(res.body);
    console.log("=== MOVIE ITEM KEYS ===");
    if (data.data && data.data[0]) {
      console.log(Object.keys(data.data[0]));
      console.log("Sample movie country & networks:", {
        country: data.data[0].country,
        networks: data.data[0].networks,
        genres: data.data[0].genres,
        releaseDate: data.data[0].releaseDate
      });
    }
  } catch (e) {
    console.error(e);
  }

  // Test 2: series pagination item
  try {
    const res = await gotScraping({
      url: `${BASE_URL}/api/series?page=1`,
      headers,
      useHeaderGenerator: false,
    });
    const data = JSON.parse(res.body);
    console.log("\n=== SERIES ITEM KEYS ===");
    if (data.data && data.data[0]) {
      console.log(Object.keys(data.data[0]));
      console.log("Sample series country & networks:", {
        country: data.data[0].country,
        networks: data.data[0].networks,
        genres: data.data[0].genres,
        firstAirDate: data.data[0].firstAirDate
      });
    }
  } catch (e) {
    console.error(e);
  }
}

main().catch(console.error);
