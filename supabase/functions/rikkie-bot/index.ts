// ============================================================
// RIKKIE BOT — Supabase Edge Function
// Automatisch beantwoord forum topics die > 1 uur oud zijn
// en nog geen Rikkie-antwoord hebben.
//
// Deploy: supabase functions deploy rikkie-bot --no-verify-jwt
// Schedule: Supabase dashboard → Edge Functions → Schedule → elke 5 min
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const OPENAI_KEY = Deno.env.get('OPENAI_API_KEY')!;

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

Deno.serve(async (_req) => {
  try {
    const result = await runRikkie();
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

async function runRikkie() {
  // Haal topics op die:
  // 1. Ouder zijn dan 1 uur
  // 2. Nog geen Rikkie-antwoord hebben
  const eenUurGeleden = new Date(Date.now() - 60 * 60 * 1000).toISOString();

  const { data: topics, error: fetchErr } = await supabase
    .from('forum_topics')
    .select('id, title, excerpt, category')
    .eq('rikkie_answered', false)
    .lt('created_at', eenUurGeleden)
    .limit(5); // Max 5 per run (kostenbeheer)

  if (fetchErr) throw fetchErr;
  if (!topics || topics.length === 0) {
    return { message: 'Geen topics om te beantwoorden.', count: 0 };
  }

  let beantwoord = 0;

  for (const topic of topics) {
    try {
      const antwoord = await vraagOpenAI(topic);

      // Voeg Rikkie-reply toe
      const { error: insertErr } = await supabase
        .from('forum_replies')
        .insert({
          topic_id: topic.id,
          author_name: 'Rikkie 🔧',
          content: antwoord,
          is_rikkie: true,
          user_id: null,
        });

      if (insertErr) throw insertErr;

      // Markeer topic als beantwoord door Rikkie
      await supabase
        .from('forum_topics')
        .update({ rikkie_answered: true })
        .eq('id', topic.id);

      beantwoord++;
    } catch (err) {
      console.error(`Fout bij topic ${topic.id}:`, err);
    }
  }

  return {
    message: `Rikkie heeft ${beantwoord} topic(s) beantwoord.`,
    count: beantwoord,
  };
}

async function vraagOpenAI(topic: {
  title: string;
  excerpt: string | null;
  category: string;
}): Promise<string> {
  const prompt = `Je bent Rikkie, een ervaren Nederlandse klusman met 20 jaar ervaring.
Je geeft praktisch, vriendelijk en to-the-point advies op een klussers-forum.
Schrijf in informeel maar correct Nederlands. Gebruik geen AI-jargon.
Geef concrete stappen, niet vaag. Max 3-4 alinea's.

Categorie: ${topic.category}
Vraag: ${topic.title}
${topic.excerpt ? `Toelichting: ${topic.excerpt}` : ''}

Geef je antwoord alsof je een ervaren klusvriend bent die reageert op dit forum.`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 500,
      temperature: 0.7,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`OpenAI fout: ${err}`);
  }

  const json = await response.json();
  return json.choices[0].message.content.trim();
}
