// مولَّد من gifts/models.js و cat-models.js و gifts.js (الأصل)
class GiftModelDef {
  final String n;
  final int p;
  final String f;
  const GiftModelDef(this.n, this.p, this.f);
}

class GiftBgDef {
  final String n, a, b;
  final int p;
  const GiftBgDef(this.n, this.a, this.b, this.p);
}

class GiftSymDef {
  final String n, d;
  final int p;
  final bool evenOdd;
  const GiftSymDef(this.n, this.p, this.d, this.evenOdd);
}

const List<GiftModelDef> pepeModels = [
  GiftModelDef('Leonardo', 10, 'leonardo'),
  GiftModelDef('Raphael', 10, 'raphael'),
  GiftModelDef('Louis Vuittoad', 10, 'louis-vuittoad'),
  GiftModelDef('Midas Pepe', 10, 'midas-pepe'),
  GiftModelDef('Cozy Galaxy', 10, 'cozy-galaxy'),
  GiftModelDef('Red Menace', 30, 'red-menace'),
  GiftModelDef('Polka Dots', 30, 'polka-dots'),
  GiftModelDef('Pumpkin', 30, 'pumpkin'),
  GiftModelDef('Stripes', 20, 'stripes'),
  GiftModelDef('Ninja Mike', 10, 'ninja-mike'),
  GiftModelDef('Yellow Hug', 30, 'yellow-hug'),
  GiftModelDef('Sketchy', 20, 'sketchy'),
  GiftModelDef('Marble', 20, 'marble'),
  GiftModelDef('Christmas', 20, 'christmas'),
  GiftModelDef('Steel Frog', 10, 'steel-frog'),
  GiftModelDef('Gucci Leap', 10, 'gucci-leap'),
  GiftModelDef('Bavaria', 20, 'bavaria'),
  GiftModelDef('Amalgam', 20, 'amalgam'),
  GiftModelDef('Toading...', 10, 'toading'),
  GiftModelDef('Hothead', 30, 'hothead'),
  GiftModelDef('Tropical', 30, 'tropical'),
  GiftModelDef('Eggplant', 30, 'eggplant'),
  GiftModelDef('Birmingham', 20, 'birmingham'),
  GiftModelDef('Donatello', 10, 'donatello'),
  GiftModelDef('Aqua Plush', 30, 'aqua-plush'),
  GiftModelDef('Red Pepple', 20, 'red-pepple'),
  GiftModelDef('Puppy Pug', 10, 'puppy-pug'),
  GiftModelDef('Pepemint', 30, 'pepemint'),
  GiftModelDef('Sunset', 20, 'sunset'),
  GiftModelDef('X-Ray', 20, 'x-ray'),
  GiftModelDef('Frozen', 20, 'frozen'),
  GiftModelDef('Princess', 20, 'princess'),
  GiftModelDef('Barcelona', 20, 'barcelona'),
  GiftModelDef('Yellow Purp', 20, 'yellow-purp'),
  GiftModelDef('Santa Pepe', 20, 'santa-pepe'),
  GiftModelDef('Emo Boi', 20, 'emo-boi'),
  GiftModelDef('Gummy Frog', 30, 'gummy-frog'),
  GiftModelDef('Fifty Shades', 10, 'fifty-shades'),
  GiftModelDef('Spectrum', 30, 'spectrum'),
  GiftModelDef('Cold Heart', 30, 'cold-heart'),
  GiftModelDef('Magnate', 10, 'magnate'),
  GiftModelDef('Poison Dart', 30, 'poison-dart'),
  GiftModelDef('Emerald Plush', 10, 'emerald-plush'),
  GiftModelDef('Pink Galaxy', 20, 'pink-galaxy'),
  GiftModelDef('Milano', 20, 'milano'),
  GiftModelDef('Pepe La Rana', 20, 'pepe-la-rana'),
  GiftModelDef('Pink Latex', 20, 'pink-latex'),
  GiftModelDef('Two Face', 20, 'two-face'),
  GiftModelDef('Hue Jester', 30, 'hue-jester'),
  GiftModelDef('Kung Fu Pepe', 20, 'kung-fu-pepe'),
];

const List<GiftModelDef> catModels = [
  GiftModelDef('Salem', 10, 'salem'),
  GiftModelDef('Blitzo', 15, 'blitzo'),
  GiftModelDef('Bubblegum', 5, 'bubblegum'),
  GiftModelDef('Oreo', 10, 'oreo'),
  GiftModelDef('Creeper', 35, 'creeper'),
  GiftModelDef('Caramel', 10, 'caramel'),
  GiftModelDef('Meowdas', 25, 'meowdas'),
  GiftModelDef('Jaddy', 10, 'jaddy'),
  GiftModelDef('Voodoo', 40, 'voodoo'),
  GiftModelDef('Gecko Cat', 15, 'gecko-cat'),
  GiftModelDef('Garfield', 5, 'garfield'),
  GiftModelDef('Goodbye Kitty', 15, 'goodbye-kitty'),
  GiftModelDef('Vampkitty', 10, 'vampkitty'),
  GiftModelDef('Cat2O', 10, 'cat2o'),
  GiftModelDef('Caustic', 30, 'caustic'),
  GiftModelDef('Instacat', 35, 'instacat'),
  GiftModelDef('Cat Nukem', 40, 'cat-nukem'),
  GiftModelDef('Purrrple', 10, 'purrrple'),
  GiftModelDef('Celestia', 30, 'celestia'),
  GiftModelDef('Silver Napper', 20, 'silver-napper'),
  GiftModelDef('Vice Kitty', 10, 'vice-kitty'),
  GiftModelDef('Purrlion', 35, 'purrlion'),
  GiftModelDef('Misty Ash', 5, 'misty-ash'),
  GiftModelDef('El Tigre', 15, 'el-tigre'),
  GiftModelDef('Virus', 40, 'virus'),
  GiftModelDef('Fern', 5, 'fern'),
  GiftModelDef('Cake', 10, 'cake'),
  GiftModelDef('Mentos', 5, 'mentos'),
  GiftModelDef('Nyan Cat', 35, 'nyan-cat'),
  GiftModelDef('Torracat', 35, 'torracat'),
  GiftModelDef('Chili Whisk', 10, 'chili-whisk'),
  GiftModelDef('Endercat', 30, 'endercat'),
  GiftModelDef('Bipolar Cat', 15, 'bipolar-cat'),
  GiftModelDef('Jeopard', 15, 'jeopard'),
  GiftModelDef('Pepe Paws', 30, 'pepe-paws'),
  GiftModelDef('Cookie', 10, 'cookie'),
  GiftModelDef('Nebula', 25, 'nebula'),
  GiftModelDef('Ruby', 15, 'ruby'),
  GiftModelDef('Copperclaw', 15, 'copperclaw'),
  GiftModelDef('Ranni', 15, 'ranni'),
  GiftModelDef('Niko', 25, 'niko'),
  GiftModelDef('Puss in Boots', 40, 'puss-in-boots'),
  GiftModelDef('Cathulhu', 30, 'cathulhu'),
  GiftModelDef('Phantom', 15, 'phantom'),
  GiftModelDef('Esmeralda', 25, 'esmeralda'),
  GiftModelDef('Vapurr', 40, 'vapurr'),
  GiftModelDef('Azuki Siam', 5, 'azuki-siam'),
  GiftModelDef('Obelisk', 20, 'obelisk'),
  GiftModelDef('Weedcat', 35, 'weedcat'),
  GiftModelDef('Yolkster', 10, 'yolkster'),
];

const List<GiftBgDef> giftBgs = [
  GiftBgDef('Chocolate', '#b8795a', '#5b3326', 30),
  GiftBgDef('Emerald', '#3fd0a0', '#0a5a40', 25),
  GiftBgDef('Sapphire', '#5784e6', '#122565', 20),
  GiftBgDef('Ruby', '#ea4b50', '#650d1a', 15),
  GiftBgDef('Black', '#26262c', '#000000', 10),
];

const List<GiftSymDef> giftSyms = [
  GiftSymDef('Moon', 30, 'M20.5 14.2A8.6 8.6 0 0 1 9.8 3.5a8.6 8.6 0 1 0 10.7 10.7z', false),
  GiftSymDef('Flame', 25, 'M12.2 2.5c.5 3.2 3.3 4.7 4.6 7.6 1.4 3.2.3 7.2-2.8 8.9a6 6 0 0 1-7.9-7.2c.5-1.6 1.6-2.6 2.5-3.9.3 1.5.9 2.3 1.9 2.6-.6-3.1.1-6.4 1.7-8z', false),
  GiftSymDef('Crown', 20, 'M3 7.5l4.2 3.6L12 4l4.8 7.1L21 7.5 19.2 18H4.8zM5 20h14v2H5z', false),
  GiftSymDef('Diamond', 15, 'M6.5 3h11L22 9l-10 12.5L2 9z', false),
  GiftSymDef('Skull', 10, 'M12 2.2c-4.6 0-8 3.2-8 7.6 0 2.5 1.1 4.3 2.6 5.5V19a1 1 0 0 0 1 1H9v1.8h1.8V20h2.4v1.8H15V20h1.4a1 1 0 0 0 1-1v-3.7c1.5-1.2 2.6-3 2.6-5.5 0-4.4-3.4-7.6-8-7.6zM8.6 12.9a2.1 2.1 0 1 1 0-4.2 2.1 2.1 0 0 1 0 4.2zm6.8 0a2.1 2.1 0 1 1 0-4.2 2.1 2.1 0 0 1 0 4.2zM12 14.2l1.2 2.3h-2.4z', true),
];
