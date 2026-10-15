#!/usr/bin/env node
// Renders the app's emoji pictures from Fluent Emoji Flat
// (https://github.com/microsoft/fluentui-emoji, MIT License, Copyright (c) Microsoft
// Corporation), pinned to one commit so a rerun gives the same files, as specs/17
// decides for content icons:
//   node scripts/emoji-pictures.mjs            (from the repo root)
// Writes app/assets/emoji/<set>/<key>.png at 48 px and the 2.0x/ and 3.0x/ variants Flutter
// picks by pixel ratio, plus the licence at app/assets/emoji/LICENSE-FluentEmoji.txt. Three sets:
//   shopping  the shopping tiles. The keys are the icon_key values the server's
//             app.catalog_icon_for() returns; app/lib/features/shopping/ui/shopping_labels.dart
//             lists them.
//   tasks     the task and reward icons, stored with the tasks; the tasks UI lists them.
//   extras    a few pictures shown next to text.
// Emoji are never drawn as text: on the web Flutter would fetch an emoji font from Google
// (NFR-9), and the pictures look the same on every platform.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const SHA = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
const RAW = `https://raw.githubusercontent.com/microsoft/fluentui-emoji/${SHA}`;

// Stable icon key -> Fluent Emoji Flat file (path under assets/, per set).
const sets = {
  shopping: {
    milk: 'Glass of milk/Flat/glass_of_milk_flat.svg',
    cheese: 'Cheese wedge/Flat/cheese_wedge_flat.svg', butter: 'Butter/Flat/butter_flat.svg',
    egg: 'Egg/Flat/egg_flat.svg', bowl: 'Bowl with spoon/Flat/bowl_with_spoon_flat.svg',
    bread: 'Bread/Flat/bread_flat.svg', baguette: 'Baguette bread/Flat/baguette_bread_flat.svg',
    pretzel: 'Pretzel/Flat/pretzel_flat.svg', croissant: 'Croissant/Flat/croissant_flat.svg',
    apple: 'Red apple/Flat/red_apple_flat.svg', pear: 'Pear/Flat/pear_flat.svg',
    banana: 'Banana/Flat/banana_flat.svg', orange: 'Tangerine/Flat/tangerine_flat.svg',
    lemon: 'Lemon/Flat/lemon_flat.svg', grapes: 'Grapes/Flat/grapes_flat.svg',
    strawberry: 'Strawberry/Flat/strawberry_flat.svg', tomato: 'Tomato/Flat/tomato_flat.svg',
    cucumber: 'Cucumber/Flat/cucumber_flat.svg', carrot: 'Carrot/Flat/carrot_flat.svg',
    potato: 'Potato/Flat/potato_flat.svg', onion: 'Onion/Flat/onion_flat.svg',
    garlic: 'Garlic/Flat/garlic_flat.svg', bell_pepper: 'Bell pepper/Flat/bell_pepper_flat.svg',
    chili: 'Hot pepper/Flat/hot_pepper_flat.svg', broccoli: 'Broccoli/Flat/broccoli_flat.svg',
    lettuce: 'Leafy green/Flat/leafy_green_flat.svg', mushroom: 'Mushroom/Flat/mushroom_flat.svg',
    avocado: 'Avocado/Flat/avocado_flat.svg', corn: 'Ear of corn/Flat/ear_of_corn_flat.svg',
    peas: 'Pea pod/Flat/pea_pod_flat.svg', beans: 'Beans/Flat/beans_flat.svg',
    pasta: 'Spaghetti/Flat/spaghetti_flat.svg', rice: 'Cooked rice/Flat/cooked_rice_flat.svg',
    salt: 'Salt/Flat/salt_flat.svg', honey: 'Honey pot/Flat/honey_pot_flat.svg',
    oil: 'Olive/Flat/olive_flat.svg', nuts: 'Peanuts/Flat/peanuts_flat.svg',
    chocolate: 'Chocolate bar/Flat/chocolate_bar_flat.svg', candy: 'Candy/Flat/candy_flat.svg',
    cookie: 'Cookie/Flat/cookie_flat.svg', cake: 'Shortcake/Flat/shortcake_flat.svg',
    ice_cream: 'Ice cream/Flat/ice_cream_flat.svg', pizza: 'Pizza/Flat/pizza_flat.svg',
    fries: 'French fries/Flat/french_fries_flat.svg',
    chicken: 'Poultry leg/Flat/poultry_leg_flat.svg', meat: 'Cut of meat/Flat/cut_of_meat_flat.svg',
    sausage: 'Hot dog/Flat/hot_dog_flat.svg', bacon: 'Bacon/Flat/bacon_flat.svg',
    fish: 'Fish/Flat/fish_flat.svg', coffee: 'Hot beverage/Flat/hot_beverage_flat.svg',
    tea: 'Teacup without handle/Flat/teacup_without_handle_flat.svg',
    juice: 'Beverage box/Flat/beverage_box_flat.svg', water: 'Droplet/Flat/droplet_flat.svg',
    soda: 'Cup with straw/Flat/cup_with_straw_flat.svg', beer: 'Beer mug/Flat/beer_mug_flat.svg',
    wine: 'Wine glass/Flat/wine_glass_flat.svg', tin: 'Canned food/Flat/canned_food_flat.svg',
    toilet_paper: 'Roll of paper/Flat/roll_of_paper_flat.svg', soap: 'Soap/Flat/soap_flat.svg',
    toothbrush: 'Toothbrush/Flat/toothbrush_flat.svg',
    lotion: 'Lotion bottle/Flat/lotion_bottle_flat.svg', sponge: 'Sponge/Flat/sponge_flat.svg',
    baby_bottle: 'Baby bottle/Flat/baby_bottle_flat.svg',
    trash: 'Wastebasket/Flat/wastebasket_flat.svg', battery: 'Battery/Flat/battery_flat.svg',
    light_bulb: 'Light bulb/Flat/light_bulb_flat.svg',
    plaster: 'Adhesive bandage/Flat/adhesive_bandage_flat.svg', pill: 'Pill/Flat/pill_flat.svg',
  },
  tasks: {
    dishes: 'Fork and knife with plate/Flat/fork_and_knife_with_plate_flat.svg',
    table: 'Spoon/Flat/spoon_flat.svg', trash: 'Wastebasket/Flat/wastebasket_flat.svg',
    bed: 'Bed/Flat/bed_flat.svg', dog: 'Dog/Flat/dog_flat.svg',
    plant: 'Seedling/Flat/seedling_flat.svg', bike: 'Bicycle/Flat/bicycle_flat.svg',
    book: 'Books/Flat/books_flat.svg', laundry: 'Basket/Flat/basket_flat.svg',
    teeth: 'Toothbrush/Flat/toothbrush_flat.svg',
    shopping: 'Shopping cart/Flat/shopping_cart_flat.svg', cooking: 'Cooking/Flat/cooking_flat.svg',
    car: 'Automobile/Flat/automobile_flat.svg', toys: 'Teddy bear/Flat/teddy_bear_flat.svg',
    star: 'Star/Flat/star_flat.svg', cinema: 'Clapper board/Flat/clapper_board_flat.svg',
    moon: 'Crescent moon/Flat/crescent_moon_flat.svg', trip: 'Compass/Flat/compass_flat.svg',
  },
  extras: {
    fire: 'Fire/Flat/fire_flat.svg', party: 'Party popper/Flat/party_popper_flat.svg',
    gift: 'Wrapped gift/Flat/wrapped_gift_flat.svg',
  },
};

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const emojiDir = path.join(root, 'app', 'assets', 'emoji');

async function fetchOk(url) {
  const res = await fetch(url);
  if (res.status !== 200) {
    throw new Error(`HTTP ${res.status} for ${url}`);
  }
  return Buffer.from(await res.arrayBuffer());
}

// Fetches the SVG at a path inside the pinned Fluent Emoji repository. The path's folder
// names contain spaces, so each segment is encoded on its own.
async function fetchSvg(key, filePath) {
  const url = `${RAW}/assets/${filePath.split('/').map(encodeURIComponent).join('/')}`;
  try {
    return await fetchOk(url);
  } catch (err) {
    throw new Error(`${key}: ${err.message}`);
  }
}

async function render(svg, px) {
  return sharp(svg, { density: 384 })
    .resize(px, px, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png({ compressionLevel: 9 })
    .toBuffer();
}

let total = 0;
for (const [set, icons] of Object.entries(sets)) {
  const outDir = path.join(emojiDir, set);
  const SIZES = [
    { dir: outDir, px: 48 },
    { dir: path.join(outDir, '2.0x'), px: 96 },
    { dir: path.join(outDir, '3.0x'), px: 144 },
  ];
  for (const { dir } of SIZES) {
    await fs.mkdir(dir, { recursive: true });
  }
  for (const key of Object.keys(icons)) {
    const svg = await fetchSvg(key, icons[key]);
    for (const { dir, px } of SIZES) {
      await fs.writeFile(path.join(dir, `${key}.png`), await render(svg, px));
    }
    total += 1;
    console.log(`${set}/${key}`);
  }
}

const license = await fetchOk(`${RAW}/LICENSE`);
await fs.writeFile(path.join(emojiDir, 'LICENSE-FluentEmoji.txt'), license);
console.log(`wrote ${total} pictures at 48, 96 and 144 px, and LICENSE-FluentEmoji.txt`);
