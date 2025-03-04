pub type Client {
  Client(api_key: String)
}

pub fn new(api_key: String) -> Client {
  Client(api_key: api_key)
}
