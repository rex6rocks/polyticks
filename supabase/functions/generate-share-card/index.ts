// generate-share-card
//
// Generates a dynamic PNG social preview card for posts.
// Pipeline: satori (JSX -> SVG) + @resvg/resvg-wasm (SVG -> PNG) -> share_previews bucket.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import satori from 'https://esm.sh/satori@0.10.13';
import { initWasm, Resvg } from 'https://esm.sh/@resvg/resvg-wasm@2.6.0';

const CARD_WIDTH = 1200;
const CARD_HEIGHT = 630;
const MAX_CONTENT_CHARS = 180;

// ---------------------------------------------------------------------------
// One-time WASM init (Resvg). Guarded so warm invocations skip it.
// ---------------------------------------------------------------------------
let wasmReady = false;
async function ensureWasm(): Promise<void> {
  if (!wasmReady) {
    await initWasm(fetch('https://esm.sh/@resvg/resvg-wasm@2.6.0/index_bg.wasm'));
    wasmReady = true;
  }
}

// ---------------------------------------------------------------------------
// Font loading: fetch Inter TTFs from Google Fonts at runtime and cache them.
// Satori requires at least one font to lay out text; without this it throws.
// ---------------------------------------------------------------------------
interface FontData {
  name: string;
  data: ArrayBuffer;
  weight: 400 | 700;
  style: 'normal';
}

let fontsCache: FontData[] | null = null;

async function loadGoogleFont(family: string, weight: 400 | 700): Promise<ArrayBuffer> {
  const cssUrl =
    `https://fonts.googleapis.com/css2?family=${encodeURIComponent(family)}` +
    `:wght@${weight}&display=swap`;
  const css = await (await fetch(cssUrl)).text();
  // Extract the opentype/truetype font URL from the CSS response.
  const urlMatch = css.match(/src:\s*url\((.+?)\)\s*format\('(opentype|truetype)'\)/);
  if (!urlMatch) throw new Error(`Could not resolve font URL for ${family} ${weight}`);
  return await (await fetch(urlMatch[1])).arrayBuffer();
}

async function getFonts(): Promise<FontData[]> {
  if (fontsCache) return fontsCache;
  const [regular, bold] = await Promise.all([
    loadGoogleFont('Inter', 400),
    loadGoogleFont('Inter', 700),
  ]);
  fontsCache = [
    { name: 'Inter', data: regular, weight: 400, style: 'normal' },
    { name: 'Inter', data: bold, weight: 700, style: 'normal' },
  ];
  return fontsCache;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function truncate(text: string, maxChars: number): string {
  const clean = text.trim();
  return clean.length <= maxChars ? clean : clean.slice(0, maxChars).trimEnd() + '…';
}

function bannerText(factCheckStatus: string | null): string {
  // 'verified_context' -> verified banner, otherwise poll banner (T4.2).
  return factCheckStatus === 'verified_context'
    ? '✓ Verified by Community'
    : 'Join the Poll on Polyticks';
}

// ---------------------------------------------------------------------------
// Card layout (1200x630, og:image standard size)
// ---------------------------------------------------------------------------
function cardElement(content: string, username: string, banner: string) {
  return {
    type: 'div',
    props: {
      style: {
        display: 'flex',
        flexDirection: 'column',
        width: '100%',
        height: '100%',
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
        padding: '60px',
        justifyContent: 'space-between',
        fontFamily: 'Inter',
        color: '#f8fafc',
      },
      children: [
        // Header: Polyticks logo/wordmark
        {
          type: 'div',
          props: {
            style: { display: 'flex', alignItems: 'center', gap: '20px' },
            children: [
              {
                type: 'div',
                props: {
                  style: {
                    display: 'flex',
                    width: '56px',
                    height: '56px',
                    borderRadius: '12px',
                    background: '#3b82f6',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '32px',
                    fontWeight: 700,
                    color: '#ffffff',
                  },
                  children: 'P',
                },
              },
              {
                type: 'div',
                props: {
                  style: { display: 'flex', fontSize: '36px', fontWeight: 700 },
                  children: 'Polyticks',
                },
              },
            ],
          },
        },
        // Body: post content, clamped within card bounds (T4.4)
        {
          type: 'div',
          props: {
            style: {
              display: 'flex',
              fontSize: '48px',
              fontWeight: 400,
              lineHeight: '1.35',
              overflow: 'hidden',
            },
            children: truncate(content, MAX_CONTENT_CHARS),
          },
        },
        // Footer: author handle + banner
        {
          type: 'div',
          props: {
            style: { display: 'flex', flexDirection: 'column', gap: '18px' },
            children: [
              {
                type: 'div',
                props: {
                  style: { display: 'flex', fontSize: '30px', color: '#94a3b8' },
                  children: `@${username}`,
                },
              },
              {
                type: 'div',
                props: {
                  style: {
                    display: 'flex',
                    alignSelf: 'flex-start',
                    padding: '14px 28px',
                    borderRadius: '9999px',
                    background: banner.startsWith('✓') ? '#22c55e' : '#3b82f6',
                    color: '#ffffff',
                    fontSize: '28px',
                    fontWeight: 700,
                  },
                  children: banner,
                },
              },
            ],
          },
        },
      ],
    },
  };
}

serve(async (req: Request) => {
  try {
    await ensureWasm();

    // 1. Validate request and get post data (accept post_id or postId)
    const body = await req.json().catch(() => ({}));
    const postId: string | undefined = body?.post_id ?? body?.postId;
    if (!postId) {
      return new Response(JSON.stringify({ error: 'post_id is required' }), { status: 400 });
    }

    // 2. Fetch post data from DB (service role: read is safe server-side)
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: post, error: dbError } = await supabase
      .from('posts')
      .select('content, author_id, fact_check_status, profiles(username)')
      .eq('id', postId)
      .single();

    if (dbError || !post) {
      // Graceful 404, nothing written to the bucket (T4.3)
      return new Response(JSON.stringify({ error: 'Post not found' }), { status: 404 });
    }

    // Embed may come back as an object or an array depending on relationship.
    const profileRaw = post.profiles as unknown;
    const username = Array.isArray(profileRaw)
      ? (profileRaw[0]?.username ?? 'user')
      : ((profileRaw as { username?: string } | null)?.username ?? 'user');

    // 3. JSX -> SVG via satori (fonts required; satori converts text to paths,
    // so resvg needs no font config)
    const fonts = await getFonts();
    const svg = await satori(
      cardElement(
        post.content ?? '',
        username,
        bannerText(post.fact_check_status),
      ) as unknown as Parameters<typeof satori>[0],
      {
        width: CARD_WIDTH,
        height: CARD_HEIGHT,
        fonts,
      },
    );

    // 4. SVG -> PNG via resvg
    const res = new Resvg(svg, {
      fitTo: { mode: 'width', value: CARD_WIDTH },
      font: { loadSystemFonts: false },
    });
    const pngData = res.render().asPng();

    // 5. Upload to share_previews bucket.
    // Keyed deterministically per post + upsert -> repeated calls overwrite the
    // same object, so the bucket never bloats (T4.5).
    const fileName = `preview_${postId}.png`;
    const { error: uploadError } = await supabase.storage
      .from('share_previews')
      .upload(fileName, pngData, { contentType: 'image/png', upsert: true });

    if (uploadError) throw uploadError;

    // 6. Get public URL
    const { data } = supabase.storage.from('share_previews').getPublicUrl(fileName);
    const publicUrl = data?.publicUrl;
    if (!publicUrl) throw new Error('Failed to resolve public URL');

    return new Response(JSON.stringify({ url: publicUrl }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500 },
    );
  }
});
