# TinyLunch site

English privacy policy and support pages for TinyLunch. Copy is limited to behaviour already described in the app, `docs/privacy-policy.md`, `docs/app-store.md`, and `PrivacyInfo.xcprivacy`.

## What Rogério needs to do

1. Create a **public** repository named `tinylunch-site` on the `rgllm` account: <https://github.com/new>
   - Owner: `rgllm`
   - Repository name: `tinylunch-site`
   - Visibility: Public
   - Leave README, .gitignore, and license empty so the first push is the site.
2. Publish the contents of this `site/` directory at the **root** of that repository (include `index.html`, `styles.css`, `privacy/`, `support/`, and `.nojekyll`):

   ```sh
   git clone https://github.com/rgllm/tinylunch-site.git
   cp -R /path/to/tinylunch/site/. tinylunch-site/
   cd tinylunch-site
   git add .
   git commit -m "Publish TinyLunch privacy and support pages"
   git push origin main
   ```

3. Enable GitHub Pages on the free plan:
   - Open `https://github.com/rgllm/tinylunch-site/settings/pages`
   - Source: **Deploy from a branch**
   - Branch: `main`, folder: `/ (root)`
   - Save
4. Wait until these URLs return HTTP 200:
   - <https://rgllm.github.io/tinylunch-site/>
   - <https://rgllm.github.io/tinylunch-site/privacy/>
   - <https://rgllm.github.io/tinylunch-site/support/>
5. In `rgllm/tinylunch`, replace the `engino.pt` privacy and support links in `README.md` and `docs/app-store.md`:
   - Privacy policy: `https://rgllm.github.io/tinylunch-site/privacy/`
   - Support: `https://rgllm.github.io/tinylunch-site/support/`

Do not change those links before the Pages URLs respond with HTTP 200. Do not change App Store Connect from this repository.
