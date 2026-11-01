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
//   meals     dishes: recipes, meal suggestions and meal wishes (meal_wish.icon_key, specs/27).
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
    // Issue #197: the starter catalogue (dictionary/shopping.txt), grouped as the file is.
    pineapple: 'Pineapple/Flat/pineapple_flat.svg', mango: 'Mango/Flat/mango_flat.svg',
    kiwi: 'Kiwi fruit/Flat/kiwi_fruit_flat.svg', peach: 'Peach/Flat/peach_flat.svg',
    cherries: 'Cherries/Flat/cherries_flat.svg', melon: 'Melon/Flat/melon_flat.svg',
    watermelon: 'Watermelon/Flat/watermelon_flat.svg',
    blueberries: 'Blueberries/Flat/blueberries_flat.svg', coconut: 'Coconut/Flat/coconut_flat.svg',
    lime: 'Lime/Flat/lime_flat.svg', ginger: 'Ginger root/Flat/ginger_root_flat.svg',
    eggplant: 'Eggplant/Flat/eggplant_flat.svg',
    sweet_potato: 'Roasted sweet potato/Flat/roasted_sweet_potato_flat.svg',
    cabbage: 'Leafy green/Flat/leafy_green_flat.svg', herb: 'Herb/Flat/herb_flat.svg',
    salad: 'Green salad/Flat/green_salad_flat.svg', chestnut: 'Chestnut/Flat/chestnut_flat.svg',
    pumpkin: 'Jack-o-lantern/Flat/jack-o-lantern_flat.svg', bagel: 'Bagel/Flat/bagel_flat.svg',
    pancakes: 'Pancakes/Flat/pancakes_flat.svg', waffle: 'Waffle/Flat/waffle_flat.svg',
    flatbread: 'Flatbread/Flat/flatbread_flat.svg', sandwich: 'Sandwich/Flat/sandwich_flat.svg',
    cupcake: 'Cupcake/Flat/cupcake_flat.svg', pie: 'Pie/Flat/pie_flat.svg',
    doughnut: 'Doughnut/Flat/doughnut_flat.svg', custard: 'Custard/Flat/custard_flat.svg',
    flour: 'Sheaf of rice/Flat/sheaf_of_rice_flat.svg', jar: 'Jar/Flat/jar_flat.svg',
    dumpling: 'Dumpling/Flat/dumpling_flat.svg', taco: 'Taco/Flat/taco_flat.svg',
    burrito: 'Burrito/Flat/burrito_flat.svg', sushi: 'Sushi/Flat/sushi_flat.svg',
    curry: 'Curry rice/Flat/curry_rice_flat.svg', soup: 'Pot of food/Flat/pot_of_food_flat.svg',
    ramen: 'Steaming bowl/Flat/steaming_bowl_flat.svg', fondue: 'Fondue/Flat/fondue_flat.svg',
    falafel: 'Falafel/Flat/falafel_flat.svg', sauce: 'Pouring liquid/Flat/pouring_liquid_flat.svg',
    rice_cracker: 'Rice cracker/Flat/rice_cracker_flat.svg',
    popcorn: 'Popcorn/Flat/popcorn_flat.svg', lollipop: 'Lollipop/Flat/lollipop_flat.svg',
    shrimp: 'Shrimp/Flat/shrimp_flat.svg', crab: 'Crab/Flat/crab_flat.svg',
    lobster: 'Lobster/Flat/lobster_flat.svg', squid: 'Squid/Flat/squid_flat.svg',
    oyster: 'Oyster/Flat/oyster_flat.svg', hamburger: 'Hamburger/Flat/hamburger_flat.svg',
    ribs: 'Meat on bone/Flat/meat_on_bone_flat.svg', turkey: 'Turkey/Flat/turkey_flat.svg',
    duck: 'Duck/Flat/duck_flat.svg', frozen: 'Snowflake/Flat/snowflake_flat.svg',
    ice: 'Ice/Flat/ice_flat.svg', bubble_tea: 'Bubble tea/Flat/bubble_tea_flat.svg',
    cocktail: 'Cocktail glass/Flat/cocktail_glass_flat.svg',
    spirits: 'Tumbler glass/Flat/tumbler_glass_flat.svg',
    champagne: 'Bottle with popping cork/Flat/bottle_with_popping_cork_flat.svg',
    mate: 'Mate/Flat/mate_flat.svg', lipstick: 'Lipstick/Flat/lipstick_flat.svg',
    nail_polish: 'Nail polish/Default/Flat/nail_polish_flat_default.svg',
    razor: 'Razor/Flat/razor_flat.svg', bathtub: 'Bathtub/Flat/bathtub_flat.svg',
    hair: 'Hair pick/Flat/hair_pick_flat.svg', glasses: 'Glasses/Flat/glasses_flat.svg',
    sun: 'Sun/Flat/sun_flat.svg',
    mask: 'Face with medical mask/Flat/face_with_medical_mask_flat.svg',
    toilet: 'Toilet/Flat/toilet_flat.svg', plunger: 'Plunger/Flat/plunger_flat.svg',
    broom: 'Broom/Flat/broom_flat.svg', bucket: 'Bucket/Flat/bucket_flat.svg',
    basket: 'Basket/Flat/basket_flat.svg', candle: 'Candle/Flat/candle_flat.svg',
    shopping_bags: 'Shopping bags/Flat/shopping_bags_flat.svg',
    kitchen_knife: 'Kitchen knife/Flat/kitchen_knife_flat.svg',
    fork_and_knife: 'Fork and knife/Flat/fork_and_knife_flat.svg',
    plate: 'Fork and knife with plate/Flat/fork_and_knife_with_plate_flat.svg',
    teapot: 'Teapot/Flat/teapot_flat.svg', pan: 'Cooking/Flat/cooking_flat.svg',
    lunchbox: 'Bento box/Flat/bento_box_flat.svg',
    container: 'Takeout box/Flat/takeout_box_flat.svg', bubbles: 'Bubbles/Flat/bubbles_flat.svg',
    fire_extinguisher: 'Fire extinguisher/Flat/fire_extinguisher_flat.svg',
    umbrella: 'Umbrella/Flat/umbrella_flat.svg', bed: 'Bed/Flat/bed_flat.svg',
    fire: 'Fire/Flat/fire_flat.svg', fireworks: 'Fireworks/Flat/fireworks_flat.svg',
    plug: 'Electric plug/Flat/electric_plug_flat.svg',
    phone: 'Mobile phone/Flat/mobile_phone_flat.svg', computer: 'Laptop/Flat/laptop_flat.svg',
    printer: 'Printer/Flat/printer_flat.svg', hammer: 'Hammer/Flat/hammer_flat.svg',
    wrench: 'Wrench/Flat/wrench_flat.svg', screwdriver: 'Screwdriver/Flat/screwdriver_flat.svg',
    nut_and_bolt: 'Nut and bolt/Flat/nut_and_bolt_flat.svg',
    saw: 'Carpentry saw/Flat/carpentry_saw_flat.svg', axe: 'Axe/Flat/axe_flat.svg',
    toolbox: 'Toolbox/Flat/toolbox_flat.svg', paintbrush: 'Paintbrush/Flat/paintbrush_flat.svg',
    ladder: 'Ladder/Flat/ladder_flat.svg', flashlight: 'Flashlight/Flat/flashlight_flat.svg',
    lock: 'Locked/Flat/locked_flat.svg', key: 'Key/Flat/key_flat.svg',
    chain: 'Chains/Flat/chains_flat.svg', hook: 'Hook/Flat/hook_flat.svg',
    clamp: 'Clamp/Flat/clamp_flat.svg', wood: 'Wood/Flat/wood_flat.svg',
    brick: 'Brick/Flat/brick_flat.svg', rope: 'Knot/Flat/knot_flat.svg',
    magnet: 'Magnet/Flat/magnet_flat.svg', package: 'Package/Flat/package_flat.svg',
    safety_pin: 'Safety pin/Flat/safety_pin_flat.svg', thread: 'Thread/Flat/thread_flat.svg',
    yarn: 'Yarn/Flat/yarn_flat.svg', scissors: 'Scissors/Flat/scissors_flat.svg',
    pen: 'Pen/Flat/pen_flat.svg', pencil: 'Pencil/Flat/pencil_flat.svg',
    crayon: 'Crayon/Flat/crayon_flat.svg', paperclip: 'Paperclip/Flat/paperclip_flat.svg',
    envelope: 'Envelope/Flat/envelope_flat.svg', notebook: 'Notebook/Flat/notebook_flat.svg',
    newspaper: 'Newspaper/Flat/newspaper_flat.svg', gift: 'Wrapped gift/Flat/wrapped_gift_flat.svg',
    balloon: 'Balloon/Flat/balloon_flat.svg', party: 'Party popper/Flat/party_popper_flat.svg',
    books: 'Books/Flat/books_flat.svg', calendar: 'Calendar/Flat/calendar_flat.svg',
    ticket: 'Ticket/Flat/ticket_flat.svg', backpack: 'Backpack/Flat/backpack_flat.svg',
    game: 'Game die/Flat/game_die_flat.svg', puzzle: 'Puzzle piece/Flat/puzzle_piece_flat.svg',
    teddy_bear: 'Teddy bear/Flat/teddy_bear_flat.svg', bicycle: 'Bicycle/Flat/bicycle_flat.svg',
    car: 'Automobile/Flat/automobile_flat.svg', tent: 'Tent/Flat/tent_flat.svg',
    seedling: 'Seedling/Flat/seedling_flat.svg',
    potted_plant: 'Potted plant/Flat/potted_plant_flat.svg',
    bouquet: 'Bouquet/Flat/bouquet_flat.svg', sunflower: 'Sunflower/Flat/sunflower_flat.svg',
    tulip: 'Tulip/Flat/tulip_flat.svg', rose: 'Rose/Flat/rose_flat.svg',
    cactus: 'Cactus/Flat/cactus_flat.svg',
    christmas_tree: 'Christmas tree/Flat/christmas_tree_flat.svg', dog: 'Dog/Flat/dog_flat.svg',
    cat: 'Cat/Flat/cat_flat.svg', bird: 'Bird/Flat/bird_flat.svg',
    rabbit: 'Rabbit/Flat/rabbit_flat.svg', paw: 'Paw prints/Flat/paw_prints_flat.svg',
    baby: 'Baby/Default/Flat/baby_flat_default.svg', t_shirt: 'T-shirt/Flat/t-shirt_flat.svg',
    socks: 'Socks/Flat/socks_flat.svg', jeans: 'Jeans/Flat/jeans_flat.svg',
    coat: 'Coat/Flat/coat_flat.svg', gloves: 'Gloves/Flat/gloves_flat.svg',
    scarf: 'Scarf/Flat/scarf_flat.svg', shoes: 'Running shoe/Flat/running_shoe_flat.svg',
    boot: 'Hiking boot/Flat/hiking_boot_flat.svg', dress: 'Dress/Flat/dress_flat.svg',
    cap: 'Billed cap/Flat/billed_cap_flat.svg',
    swimsuit: 'One-piece swimsuit/Flat/one-piece_swimsuit_flat.svg',
    clothes: 'Womans clothes/Flat/womans_clothes_flat.svg', pick: 'Pick/Flat/pick_flat.svg',
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
  // Dishes: the pictures of recipes, meal suggestions and meal wishes (specs/27
  // "Wunschessen"); meal_wish.icon_key, and the icon_key app.meal_icon_for() picks from a
  // title. app/lib/features/rituals/domain/meal_icons.dart lists them.
  meals: {
    pizza: 'Pizza/Flat/pizza_flat.svg', pasta: 'Spaghetti/Flat/spaghetti_flat.svg',
    pancakes: 'Pancakes/Flat/pancakes_flat.svg', waffle: 'Waffle/Flat/waffle_flat.svg',
    burger: 'Hamburger/Flat/hamburger_flat.svg', fries: 'French fries/Flat/french_fries_flat.svg',
    hotdog: 'Hot dog/Flat/hot_dog_flat.svg', sandwich: 'Sandwich/Flat/sandwich_flat.svg',
    taco: 'Taco/Flat/taco_flat.svg', burrito: 'Burrito/Flat/burrito_flat.svg',
    kebab: 'Stuffed flatbread/Flat/stuffed_flatbread_flat.svg',
    curry: 'Curry rice/Flat/curry_rice_flat.svg', rice: 'Cooked rice/Flat/cooked_rice_flat.svg',
    noodles: 'Steaming bowl/Flat/steaming_bowl_flat.svg', soup: 'Pot of food/Flat/pot_of_food_flat.svg',
    paella: 'Shallow pan of food/Flat/shallow_pan_of_food_flat.svg',
    salad: 'Green salad/Flat/green_salad_flat.svg', sushi: 'Sushi/Flat/sushi_flat.svg',
    dumpling: 'Dumpling/Flat/dumpling_flat.svg', chicken: 'Poultry leg/Flat/poultry_leg_flat.svg',
    fish: 'Fish/Flat/fish_flat.svg', meat: 'Cut of meat/Flat/cut_of_meat_flat.svg',
    egg: 'Cooking/Flat/cooking_flat.svg', falafel: 'Falafel/Flat/falafel_flat.svg',
    fondue: 'Fondue/Flat/fondue_flat.svg', pie: 'Pie/Flat/pie_flat.svg',
    cake: 'Shortcake/Flat/shortcake_flat.svg', ice_cream: 'Ice cream/Flat/ice_cream_flat.svg',
    bread: 'Bread/Flat/bread_flat.svg', pretzel: 'Pretzel/Flat/pretzel_flat.svg',
    croissant: 'Croissant/Flat/croissant_flat.svg',
    potato: 'Roasted sweet potato/Flat/roasted_sweet_potato_flat.svg',
    cheese: 'Cheese wedge/Flat/cheese_wedge_flat.svg',
    porridge: 'Bowl with spoon/Flat/bowl_with_spoon_flat.svg',
    vegetables: 'Broccoli/Flat/broccoli_flat.svg',
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
