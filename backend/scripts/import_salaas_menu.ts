import * as cheerio from 'cheerio';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function importMenu() {
  console.log('Fetching menu...');
  const res = await fetch('https://m.1menu.com.tr/salaascafe/');
  const html = await res.text();
  const $ = cheerio.load(html);

  const business = await prisma.business.findFirst();
  if (!business) {
    console.error('No business found in database.');
    process.exit(1);
  }

  console.log(`Using business: ${business.name}`);

  const categories: any[] = [];

  // Extract categories
  $('#pills-tab .nav-item button').each((i, el) => {
    const name = $(el).text().trim();
    const targetId = $(el).attr('data-bs-target'); // e.g. #pills-tabKahvaltı
    categories.push({ name, targetId });
  });

  console.log(`Found ${categories.length} categories.`);

  for (let i = 0; i < categories.length; i++) {
    const catData = categories[i];
    console.log(`Processing category: ${catData.name}`);

    // Insert category
    const category = await prisma.category.create({
      data: {
        businessId: business.id,
        name: catData.name,
        sortOrder: i,
        isActive: true,
      }
    });

    // Find products
    const pane = $(catData.targetId);
    const products = pane.find('.cat-pricing-list');

    const productsArray = products.toArray();
    for (const prodEl of productsArray) {
      const $prod = $(prodEl);
      
      const titleEl = $prod.find('.cat-pricing-title h4').clone();
      titleEl.children().remove();
      const name = titleEl.text().trim();

      if (!name) continue;

      const priceText = $prod.find('.cat-price').text().trim();
      const priceVal = parseInt(priceText.replace(/[^\d]/g, '') || '0', 10);
      const priceCents = priceVal * 100;

      let rawDesc = $prod.find('p').text().trim();
      const extras: { name: string; price: number }[] = [];
      const cleanDescLines: string[] = [];

      const lines = rawDesc.split('\n');
      for (let line of lines) {
        line = line.trim();
        if (!line) continue;
        
        // Check for extras like "Ekstra Sucuklu 50" or "Ekstra Kaşarlı +50"
        const match = line.match(/(Ekstra[^0-9]+)\+?(\d+)/i);
        if (match) {
          extras.push({
            name: match[1].replace(/[-:]/g, '').trim(),
            price: parseInt(match[2], 10) * 100
          });
        } else {
          cleanDescLines.push(line);
        }
      }

      const description = cleanDescLines.join('\n').trim();

      // Insert product
      const product = await prisma.product.create({
        data: {
          businessId: business.id,
          categoryId: category.id,
          name,
          priceCents,
          description: description.substring(0, 255), // Max 255 chars
          isActive: true
        }
      });

      // Insert extras if any
      if (extras.length > 0) {
        // Create modifier group
        const group = await prisma.productModifierGroup.create({
          data: {
            productId: product.id,
            name: 'Ekstralar',
            isRequired: false,
            minSelect: 0,
            maxSelect: extras.length
          }
        });

        // Create modifier items
        for (const ext of extras) {
          await prisma.productModifierItem.create({
            data: {
              modifierGroupId: group.id,
              name: ext.name,
              priceCents: ext.price,
              isActive: true
            }
          });
        }
      }

      console.log(`  - Added: ${name} (${priceCents / 100} TL)`);
    }
  }

  console.log('Import completed successfully!');
}

importMenu().catch(console.error).finally(() => prisma.$disconnect());
