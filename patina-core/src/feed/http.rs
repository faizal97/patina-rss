use crate::PatinaError;

/// Create a configured HTTP client for feed fetching
pub fn create_client() -> Result<reqwest::blocking::Client, PatinaError> {
    reqwest::blocking::Client::builder()
        .user_agent("Patina RSS Reader/1.0")
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(Into::into)
}
