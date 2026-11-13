import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// One markdown file per experience. Add a file and it appears on the home
// page and the Experiences page, in `order`.
const experiences = defineCollection({
  loader: glob({ pattern: '*.md', base: './src/content/experiences' }),
  schema: z.object({
    title: z.string(),
    kind: z.string(),
    summary: z.string(),
    order: z.number(),
  }),
});

export const collections = { experiences };
