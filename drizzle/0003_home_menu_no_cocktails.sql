-- the homepage menu block shows food only: take cocktails/drinks off the homepage (they stay on the menu page)
UPDATE "menu_items" SET "featured" = false WHERE "featured" = true AND "category_id" IN (SELECT "id" FROM "menu_categories" WHERE "section" <> 'Food');
