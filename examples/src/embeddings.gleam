import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleamstral/client
import gleamstral/embeddings/embeddings
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// cd examples && gleam run -m embeddings

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  let client = client.new(api_key)
  let embeddings = embeddings.new(client)

  let inputs = [
    "Hello, world!", "Embeddings are vector representations of text.",
    "Gleamstral makes it easy to work with Mistral AI.",
  ]

  io.println(
    "Generating embeddings for "
    <> int.to_string(list.length(inputs))
    <> " texts...",
  )

  let result = embeddings.create(embeddings, model.MistralEmbed, inputs)

  case result {
    Ok(response) -> {
      io.println("Successfully generated embeddings!")
      io.println("Model: " <> response.model)
      io.println("Object: " <> response.object)
      io.println("ID: " <> response.id)

      // Print information about each embedding
      list.each(response.data, fn(data) {
        io.println("\nEmbedding #" <> int.to_string(data.index) <> ":")
        io.println("Dimensions: " <> int.to_string(list.length(data.embedding)))

        // Print the first 5 dimensions of the embedding vector
        let preview =
          data.embedding
          |> list.take(5)
          |> list.map(float.to_string)
          |> string.join(", ")

        io.println("First 5 dimensions: [" <> preview <> ", ...]")
      })

      io.println("\nUsage:")
      io.println(
        "Prompt tokens: " <> int.to_string(response.usage.prompt_tokens),
      )
      io.println("Total tokens: " <> int.to_string(response.usage.total_tokens))
    }

    Error(error) -> {
      io.println("Error generating embeddings: " <> error)
    }
  }
}
