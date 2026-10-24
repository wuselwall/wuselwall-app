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
//   events    the icons of events, countdowns and traditions (event.icon_key, specs/27).
//   scenes    the modules' header illustrations (specs/26).
//   avatars   the pictures a member can pick instead of their initial (profile.avatar_key);
//             app/lib/features/identity/domain/avatars.dart lists them.
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
  // Icons of events, countdowns and traditions (specs/27); event.icon_key.
  events: {
    cake: 'Birthday cake/Flat/birthday_cake_flat.svg', game_die: 'Game die/Flat/game_die_flat.svg',
    pizza: 'Pizza/Flat/pizza_flat.svg', cinema: 'Clapper board/Flat/clapper_board_flat.svg',
    croissant: 'Croissant/Flat/croissant_flat.svg', book: 'Books/Flat/books_flat.svg',
    hiking: 'Hiking boot/Flat/hiking_boot_flat.svg', beach: 'Beach with umbrella/Flat/beach_with_umbrella_flat.svg',
    plane: 'Airplane/Flat/airplane_flat.svg', zoo: 'Lion/Flat/lion_flat.svg',
    tent: 'Camping/Flat/camping_flat.svg', football: 'Soccer ball/Flat/soccer_ball_flat.svg',
    music: 'Musical notes/Flat/musical_notes_flat.svg', gift: 'Wrapped gift/Flat/wrapped_gift_flat.svg',
    balloon: 'Balloon/Flat/balloon_flat.svg', backpack: 'Backpack/Flat/backpack_flat.svg',
    swim: 'Water wave/Flat/water_wave_flat.svg', ferris: 'Ferris wheel/Flat/ferris_wheel_flat.svg',
    house: 'House/Flat/house_flat.svg', star: 'Star/Flat/star_flat.svg',
  },
  // The modules' header illustrations (specs/26 "Module bands").
  scenes: {
    sun: 'Sun/Flat/sun_flat.svg', calendar: 'Spiral calendar/Flat/spiral_calendar_flat.svg',
    broom: 'Broom/Flat/broom_flat.svg', pot: 'Pot of food/Flat/pot_of_food_flat.svg',
    basket: 'Basket/Flat/basket_flat.svg', backpack: 'Backpack/Flat/backpack_flat.svg',
  },
  avatars: {
    cat: 'Cat face/Flat/cat_face_flat.svg', dog: 'Dog face/Flat/dog_face_flat.svg',
    fox: 'Fox/Flat/fox_flat.svg', lion: 'Lion/Flat/lion_flat.svg',
    tiger: 'Tiger face/Flat/tiger_face_flat.svg', panda: 'Panda/Flat/panda_flat.svg',
    koala: 'Koala/Flat/koala_flat.svg', rabbit: 'Rabbit face/Flat/rabbit_face_flat.svg',
    bear: 'Bear/Flat/bear_flat.svg', frog: 'Frog/Flat/frog_flat.svg',
    unicorn: 'Unicorn/Flat/unicorn_flat.svg', owl: 'Owl/Flat/owl_flat.svg',
    penguin: 'Penguin/Flat/penguin_flat.svg', dolphin: 'Dolphin/Flat/dolphin_flat.svg',
    butterfly: 'Butterfly/Flat/butterfly_flat.svg', dino: 'T-rex/Flat/t-rex_flat.svg',
    rocket: 'Rocket/Flat/rocket_flat.svg', football: 'Soccer ball/Flat/soccer_ball_flat.svg',
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

// Sets named on the command line only (`node scripts/emoji-pictures.mjs events`), so adding a
// set does not rewrite the others' files; all of them without arguments.
const only = process.argv.slice(2);
let total = 0;
for (const [set, icons] of Object.entries(sets)) {
  if (only.length > 0 && !only.includes(set)) continue;
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
