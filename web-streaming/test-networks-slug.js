import { gotScraping } from "got-scraping";

const BASE_URL = "https://z2.idlixku.com";
const headers = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

async function testQuery(url) {
  try {
    const res = await gotScraping({
      url,
      headers,
      useHeaderGenerator: false,
    });
    const data = JSON.parse(res.body);
    console.log(`\nGET ${url}`);
    console.log(`Status: ${res.statusCode}`);
    console.log(`Total: ${data.pagination?.total || data.total}`);
    if (data.data && data.data[0]) {
      console.log(`First item title: ${data.data[0].title}`);
    }
  } catch (err) {
    console.log(`\nGET ${url} - Error:`, err.message);
  }
}

async function main() {
  // Let's test different query params for networks
  await testQuery(`${BASE_URL}/api/series?networks=netflix&limit=5`);
  await testQuery(`${BASE_URL}/api/series?networks=213&limit=5`);
  await testQuery(`${BASE_URL}/api/series?networkId=213&limit=5`);
  await testQuery(`${BASE_URL}/api/series?network_id=213&limit=5`);
  
  // Let's test direct network endpoint
  await testQuery(`${BASE_URL}/api/network/netflix?limit=5`);
  await testQuery(`${BASE_URL}/api/network/213?limit=5`);
  await testQuery(`${BASE_URL}/api/networks/netflix?limit=5`);
  await testQuery(`${BASE_URL}/api/networks/213?limit=5`);
}

main().catch(console.error);
