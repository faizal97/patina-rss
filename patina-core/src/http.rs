// HTTP utilities module
// Currently using reqwest directly in other modules
// This module can be expanded for shared HTTP configuration

use reqwest::blocking::Client;
use std::time::Duration;

/// Create a configured HTTP client
pub fn create_client() -> Result<Client, reqwest::Error> {
    Client::builder()
        .user_agent("Patina RSS Reader/1.0")
        .timeout(Duration::from_secs(30))
        .build()
}
