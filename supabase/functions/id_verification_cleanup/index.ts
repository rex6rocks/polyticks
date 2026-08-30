//
// id_verification_cleanup
//
// Supabase Edge Function to delete ID images from storage when verification status updates.
//

// @ts-ignore: Deno npm / esm import resolution in standard IDEs
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// In modern Supabase / Deno, Deno.serve is built-in
Deno.serve(async (req: Request) => {
  try {
    const { record } = await req.json();

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Extract user ID and status from the record
    const userId = record?.id;
    const status = record?.verification_status;

    // Only proceed if status is 'approved' or 'rejected'
    if (status !== 'approved' && status !== 'rejected') {
      return new Response(
        JSON.stringify({ success: false, message: 'No action needed' }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    // Note: per-user folder layout ('${userId}/id_verification.jpg') since V4.
    const filename = `${userId}/id_verification.jpg`;

    // Delete the ID image from storage
    const { error } = await supabase.storage
      .from('id-verifications')
      .remove([filename]);

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});