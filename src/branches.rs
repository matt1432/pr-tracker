// SPDX-License-Identifier: AGPL-3.0-or-later WITH GPL-3.0-linking-exception
// SPDX-FileCopyrightText: 2021, 2023 Alyssa Ross <hi@alyssa.is>
// SPDX-FileCopyrightText: 2022 Arnout Engelen <arnout@bzzt.net>

use std::borrow::Cow;
use std::collections::BTreeMap;

use once_cell::sync::Lazy;
use regex::{Regex, RegexSet};

const NEXT_BRANCH_TABLE: [(&str, &str); 12] = [
    (r"\Apython-updates\z", "staging"),
    (r"\Astaging\z", "staging-next"),
    (r"\Astaging-next\z", "master"),
    (r"\Astaging-next-([\d.]+)\z", "release-$1"),
    (r"\Ahaskell-updates\z", "master"),
    (r"\Amaster\z", "nixpkgs-unstable"),
    (r"\Amaster\z", "nixos-unstable-small"),
    (r"\Anixos-(.*)-small\z", "nixos-$1"),
    (r"\Arelease-([\d.]+)\z", "nixpkgs-$1-darwin"),
    (r"\Arelease-([\d.]+)\z", "nixos-$1-small"),
    (r"\Astaging-((1.|20)\.\d{2})\z", "release-$1"),
    (r"\Astaging-((2[1-9]|[3-90].)\.\d{2})\z", "staging-next-$1"),
];

const BRANCH_HYDRA_LINK_TABLE: [(&str, &str); 5] = [
    (r"\Apython-updates\z", "nixpkgs/python-updates"),
    (r"\Astaging-next\z", "nixpkgs/staging-next"),
    // There's no staging-next-21.11 for some reason.
    (
        r"\Astaging-next-([013-9]\d\.\d{2}|2(1\.05|[2-90]\.\d{2}))\z",
        "nixpkgs/staging-next-$1",
    ),
    (r"\Ahaskell-updates\z", "nixpkgs/haskell-updates"),
    (r"\Amaster\z", "nixpkgs/trunk"),
];

const CHANNEL_HYDRA_LINK_TABLE: [(&str, &str); 4] = [
    (r"\Anixpkgs-unstable\z", "nixpkgs/trunk/unstable"),
    (r"\Anixos-unstable-small\z", "nixos/unstable-small/tested"),
    (r"\Anixos-unstable\z", "nixos/trunk-combined/tested"),
    (r"\Anixos-(\d.*)\z", "nixos/release-$1/tested"),
];

static BRANCH_NEXTS: Lazy<BTreeMap<&str, Vec<&str>>> = Lazy::new(|| {
    NEXT_BRANCH_TABLE
        .iter()
        .fold(BTreeMap::new(), |mut map, (pattern, next)| {
            map.entry(pattern).or_insert_with(Vec::new).push(next);
            map
        })
});

static BRANCH_NEXTS_BY_INDEX: Lazy<Vec<&Vec<&str>>> = Lazy::new(|| BRANCH_NEXTS.values().collect());

static BRANCH_PATTERNS: Lazy<Vec<Regex>> = Lazy::new(|| {
    BRANCH_NEXTS
        .keys()
        .copied()
        .map(Regex::new)
        .map(Result::unwrap)
        .collect()
});

static BRANCH_REGEXES: Lazy<RegexSet> = Lazy::new(|| RegexSet::new(BRANCH_NEXTS.keys()).unwrap());

pub fn next_branches(branch: &str) -> Vec<Cow<str>> {
    BRANCH_REGEXES
        .matches(branch)
        .iter()
        .flat_map(|index| {
            let regex = BRANCH_PATTERNS.get(index).unwrap();
            BRANCH_NEXTS_BY_INDEX
                .get(index)
                .unwrap()
                .iter()
                .map(move |next| regex.replace(branch, *next))
        })
        .collect()
}

static BRANCH_HYDRA_LINK_PATTERNS: Lazy<Vec<Regex>> = Lazy::new(|| {
    BRANCH_HYDRA_LINKS
        .keys()
        .copied()
        .map(Regex::new)
        .map(Result::unwrap)
        .collect()
});

static BRANCH_HYDRA_LINKS: Lazy<BTreeMap<&str, String>> = Lazy::new(|| {
    let branch_links = BRANCH_HYDRA_LINK_TABLE.iter().map(|(pattern, jobset)| {
        (
            *pattern,
            format!("https://hydra.nixos.org/jobset/{jobset}#tabs-jobs"),
        )
    });
    let channel_links = CHANNEL_HYDRA_LINK_TABLE.iter().map(|(pattern, job)| {
        (
            *pattern,
            format!("https://hydra.nixos.org/job/{job}#tabs-constituents"),
        )
    });
    branch_links.chain(channel_links).collect()
});

static BRANCH_HYDRA_LINKS_BY_INDEX: Lazy<Vec<String>> =
    Lazy::new(|| BRANCH_HYDRA_LINKS.values().cloned().collect());

static BRANCH_HYDRA_LINK_REGEXES: Lazy<RegexSet> =
    Lazy::new(|| RegexSet::new(BRANCH_HYDRA_LINKS.keys()).unwrap());

pub fn branch_hydra_link(branch: &str) -> Option<String> {
    BRANCH_HYDRA_LINK_REGEXES
        .matches(branch)
        .iter()
        .next()
        .and_then(|index| {
            let regex = BRANCH_HYDRA_LINK_PATTERNS.get(index).unwrap();
            BRANCH_HYDRA_LINKS_BY_INDEX
                .get(index)
                .map(move |link| regex.replace(branch, link).to_string())
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn python_updates() {
        let res = next_branches("python-updates");
        assert_eq!(res, vec!["staging"]);
    }

    #[test]
    fn staging_next() {
        let branch = "staging-next";
        let res = next_branches(branch);
        assert_eq!(res, vec!["master"]);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/jobset/nixpkgs/staging-next#tabs-jobs";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn staging_18_03() {
        let branch = "staging-18.03";
        let next = next_branches(branch);
        assert_eq!(next, vec!["release-18.03"]);
        let link = branch_hydra_link(branch);
        assert_eq!(link, None);
    }

    #[test]
    fn staging_20_09() {
        let res = next_branches("staging-20.09");
        assert_eq!(res, vec!["release-20.09"]);
    }

    #[test]
    fn staging_21_05() {
        let res = next_branches("staging-21.05");
        assert_eq!(res, vec!["staging-next-21.05"]);
    }

    #[test]
    fn staging_30_05() {
        let res = next_branches("staging-30.05");
        assert_eq!(res, vec!["staging-next-30.05"]);
    }

    #[test]
    fn staging_00_11() {
        let res = next_branches("staging-00.11");
        assert_eq!(res, vec!["staging-next-00.11"]);
    }

    #[test]
    fn staging_next_21_05() {
        let branch = "staging-next-21.05";
        let res = next_branches(branch);
        assert_eq!(res, vec!["release-21.05"]);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/jobset/nixpkgs/staging-next-21.05#tabs-jobs";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn staging_next_21_11() {
        let branch = "staging-next-21.11";
        let next = next_branches(branch);
        assert_eq!(next, vec!["release-21.11"]);
        assert!(branch_hydra_link(branch).is_none());
    }

    #[test]
    fn staging_next_22_05() {
        let branch = "staging-next-22.05";
        let next = next_branches(branch);
        assert_eq!(next, vec!["release-22.05"]);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/jobset/nixpkgs/staging-next-22.05#tabs-jobs";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn staging_next_30_05() {
        let branch = "staging-next-30.05";
        let next = next_branches(branch);
        assert_eq!(next, vec!["release-30.05"]);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/jobset/nixpkgs/staging-next-30.05#tabs-jobs";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn haskell_updates() {
        let branch = "haskell-updates";
        let next = next_branches(branch);
        assert_eq!(next, vec!["master"]);
    }

    #[test]
    fn master() {
        let branch = "master";
        let next = next_branches(branch);
        assert_eq!(next, vec!["nixpkgs-unstable", "nixos-unstable-small"]);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/jobset/nixpkgs/trunk#tabs-jobs";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn release_20_09() {
        let res = next_branches("release-20.09");
        assert_eq!(res, vec!["nixpkgs-20.09-darwin", "nixos-20.09-small"]);
    }

    #[test]
    fn nixpkgs_unstable() {
        let branch = "nixpkgs-unstable";
        let next = next_branches(branch);
        assert!(next.is_empty());
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/job/nixpkgs/trunk/unstable#tabs-constituents";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn nixos_unstable_small() {
        let branch = "nixos-unstable-small";
        let next = next_branches(branch);
        assert_eq!(next, vec!["nixos-unstable"]);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/job/nixos/unstable-small/tested#tabs-constituents";
        assert_eq!(link.unwrap(), expected);
    }

    #[test]
    fn nixos_unstable() {
        let branch = "nixos-unstable";
        let next = next_branches(branch);
        assert_eq!(next.len(), 0);
        let link = branch_hydra_link(branch);
        let expected = "https://hydra.nixos.org/job/nixos/trunk-combined/tested#tabs-constituents";
        assert_eq!(link.unwrap(), expected);
    }
}
