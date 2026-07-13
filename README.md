<p align="center">
  <img src="streaming_mobile/assets/images/apps.icon.png" width="128" height="128" alt="StreamVault Logo" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Riverpod-4752B6?style=for-the-badge&logo=dart&logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions" />
</p>

# StreamVault

StreamVault is a modern streaming application built with Flutter, designed to offer high-performance video playbacks and synchronized metadata parsing using a localized backend architecture.

## Main Features

* Just-In-Time Synchronization: Automatically fetches and synchronizes content catalogs and metadata when detail pages are opened.
* Adaptive Bitrate Video Player: Embedded HLS player that supports auto-scaling of video resolutions based on network bandwidth.
* Intelligent Headless Bypass: Performs cookie harvesting in the background to handle web security barriers smoothly, with an interactive visual fallback when necessary.
* Advanced Curation Filters: Allows browsing content based on genres, production countries, release years, and networks.
* Cinematic Glow Interface: Premium dark UI featuring dynamic backdrop glows and auto-hide player control states.

## Architecture and Patterns

The codebase is organized using a feature-first clean architecture pattern to ensure maintainability and testability.

### Project Structure
* core: Houses shared modules such as network clients, routing, theme systems, and utility services.
* features: Organized by functional domains (home, detail, search). Each feature folder contains its own layers:
  * data: Models, datasources, and repository implementations.
  * domain: Providers and business logic.
  * presentation: Widgets, screens, and UI elements.
* shared: Reusable atomic widgets, molecules, and organisms (such as custom player UI components).

### Key Patterns
* MVVM (Model-View-ViewModel): Used in conjunction with Riverpod to separate UI rendering from business states.
* Repository Pattern: Abstracts data storage and remote API fetches behind clean interfaces.
* State Management: Riverpod is used for declarative, reactive state flow and dependency injection.

## Acknowledgments

We would like to thank TMDB (The Movie Database) for providing their comprehensive public API which powers our rich metadata, including titles, descriptions, posters, and cast details.

## Creator

<table align="left" style="border-collapse: collapse; border: none; border-spacing: 0px;">
  <tr style="border: none;">
    <td align="center" valign="middle" style="border: none; padding-right: 15px; padding-bottom: 15px;">
      <img src="https://github.com/havilz.png" width="96" height="96" style="border-radius: 50%; display: block;" alt="havilz lating" />
    </td>
    <td align="left" valign="middle" style="border: none; padding-bottom: 15px;">
      <h3 style="margin: 0 0 4px 0; border: none; font-size: 1.4em;">havilz lating</h3>
      <p style="margin: 0 0 12px 0; color: #8b949e; font-size: 0.95em;">StreamVault Creator</p>
      <a href="mailto:havilzlating05@gmail.com" style="text-decoration: none;">
        <img src="https://img.shields.io/badge/Email-D14836?style=flat-square&logo=gmail&logoColor=white" alt="Email" />
      </a>
      <a href="https://www.tiktok.com/@aftermid_night?_r=1&_t=ZS-97zfBpWVayI" target="_blank" style="text-decoration: none;">
        <img src="https://img.shields.io/badge/TikTok-000000?style=flat-square&logo=tiktok&logoColor=white" alt="TikTok" />
      </a>
      <a href="https://www.instagram.com/havilz__?igsh=azZucjg1YjN4Mm04" target="_blank" style="text-decoration: none;">
        <img src="https://img.shields.io/badge/Instagram-E4405F?style=flat-square&logo=instagram&logoColor=white" alt="Instagram" />
      </a>
      <a href="https://x.com/HLating85988" target="_blank" style="text-decoration: none;">
        <img src="https://img.shields.io/badge/X-000000?style=flat-square&logo=x&logoColor=white" alt="X/Twitter" />
      </a>
      <a href="https://www.threads.net/@havilz__" target="_blank" style="text-decoration: none;">
        <img src="https://img.shields.io/badge/Threads-000000?style=flat-square&logo=threads&logoColor=white" alt="Threads" />
      </a>
    </td>
  </tr>
</table>

<br clear="left" />


