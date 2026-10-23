# Generated food photos

Built-in `image_gen` mode produced ten original square, photorealistic editorial
food photos. Every prompt requested a centered dish with room for a square crop,
a pale warm stone tabletop, soft natural daylight, natural appetizing textures,
and no people, hands, text, labels, logos, borders, or collage.

| Asset in `asset/image/food/` | Subject prompt |
|---|---|
| `yogurt_oats_berries.jpg` | White ceramic bowl of thick Greek yogurt topped with rolled oats, blueberries, raspberries, sliced strawberries, walnuts, and mint. |
| `grilled_chicken_rice.jpg` | Sliced grilled chicken breast with cooked basmati rice, broccoli, and small roasted vegetables. |
| `chicken_kabsa.jpg` | Traditional Saudi chicken kabsa: golden spiced rice, roasted chicken leg, almonds, and herbs in a white shallow bowl. |
| `milk_tea.jpg` | Clear glass of warm, pale tan milk tea on a white saucer with subtle steam and a few tea leaves. |
| `rice_boiled_eggs.jpg` | Simple plate of fluffy white cooked rice and sliced hard-boiled eggs, with only a small natural garnish. |
| `red_apple.jpg` | One whole shiny red apple with small water droplets. |
| `protein_milk.jpg` | Clear glass of creamy plain high-protein milk shake with gentle foam and no product packaging. |
| `rolled_oats.jpg` | White ceramic bowl of plain uncooked rolled oats, without toppings. |
| `dolma.jpg` | Traditional stuffed grape-leaf dolma on a white shallow plate with a lemon wedge. |
| `shawarma_broasted.jpg` | Middle Eastern platter of sliced chicken shawarma and crispy broasted chicken with separate garlic and chili sauces. |

The generated PNG originals were reviewed, then converted with FFmpeg to 512px
JPEG assets for the app. The built-in originals remain in Codex's generated
image store. The ten bundled photos total about 905 KB. The app does not
upload these to Firebase Storage; they are delivered with the installed APK.
