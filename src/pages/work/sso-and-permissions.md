---
layout: ../../layouts/CaseStudy.astro
title: SSO and permissions, built as a junior
description: How I built single sign-on and fine-grained permissions for a platform using Spring Boot, Spring Security and SAML.
---

<p class="case-label">login &amp; permissions</p>

# SSO and permissions, built as a junior

<p class="case-intro">Our platform needed two things: a way to sign in with Google, and a better answer to “who's allowed to do what” than a handful of hard-coded roles. I did build both.</p>

<p class="case-meta">junior dev on a team of four · Aug 2025 – Jan 2026 · Spring Boot, Spring Security, SAML</p>

<div class="stats" aria-label="In numbers">
  <div><strong>~150</strong><span>permissions across 9 roles, and still growing</span></div>
  <div><strong>2 → 1</strong><span>ways to log in the early stages, Google or Email/PW, later we moved to only Google login</span></div>
</div>

## How it works

<figure class="auth-diagram">
  <div class="auth-flow"><span>You</span><b aria-hidden="true">→</b><span class="auth-active">Auth service</span><b aria-hidden="true">↔</b><span>Google</span></div>
  <div class="auth-down" aria-hidden="true">↓</div>
  <div class="auth-result"><strong>One session + your permissions</strong><small>every other service just reads this</small></div>
  <figcaption>You sign in once with Google. After that, every service sees the same user with the same permissions.</figcaption>
</figure>

## Why it works this way

### Let Google handle the hard part

The push for SSO came from NIS2: our login had to get more secure. Building that ourselves would have meant handling key generation, cryptographic protection and everything around passwords, on a team of four. So I suggested moving login to Google with SAML and letting a provider that does this full-time carry that weight. The team agreed, and I built it. It looks like the lazy route, but it's also the safer one.

### Permissions, not just roles

This part was already planned by the team; so I decided to build it. Every endpoint asks for its own permission, and roles like Operator, Driver and Admin are just bundles of them.  So a new role means picking permissions, not touching controllers. And if someone needs one extra thing, like creating accounts without being an Admin, they can get exactly that one permission.

### A Google user is just a user

Once Google confirms who you are, you become exactly the same kind of user as someone who logged in with a password. One path for everything after login, no special cases.

### No surprise accounts

Having a company Google account isn't enough to get in. You have to exist in the system first, so a person still decides who has access.