import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { image } = await req.json()
    const openAiKey = Deno.env.get('OPENAI_API_KEY')

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "user",
            content: [
              { 
                type: "text", 
                text: "You are a smart marketplace assistant. Analyze this image and provide a highly optimized product listing. Return ONLY a JSON object matching this exact schema, with no markdown formatting or backticks: { \"title\": \"Short descriptive title\", \"price\": 100, \"description\": \"A compelling, 3 sentence description for a buyer.\", \"category\": \"For Sale\", \"subCategory\": \"Furniture\", \"condition\": \"Good\" } Valid categories: For Sale, Housing, Jobs, Community, Services, Gigs." 
              },
              { type: "image_url", image_url: { url: `data:image/jpeg;base64,${image}` } }
            ]
          }
        ],
        max_tokens: 300
      })
    })

    const data = await response.json()

    if (!response.ok) {
        return new Response(JSON.stringify({ error: "OpenAI Error", details: data }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }

    const content = data.choices[0].message.content
    
    // Server-Side Cleanup: Strip out OpenAI's markdown formatting
    let cleanContent = content.replace(/```json/g, "").replace(/```/g, "").trim();
    
    // Parse it into an actual object so Swift receives a perfect JSON payload
    const parsedJson = JSON.parse(cleanContent);

    return new Response(JSON.stringify(parsedJson), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal Server Error", message: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})