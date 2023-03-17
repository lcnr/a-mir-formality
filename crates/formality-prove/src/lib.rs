use formality_types::derive_links;

mod db;
mod decls;
mod prove;

pub use decls::*;
pub use prove::prove;
pub use prove::prove_is_local_trait_ref;
pub use prove::Env;

#[cfg(test)]
mod test;
