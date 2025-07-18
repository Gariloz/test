# LootLog - WoW 3.3.5a Addon

LootLog is a comprehensive loot tracking addon for World of Warcraft 3.3.5a that records and displays all items you've looted during your adventures.

**🎯 Latest Version: v1.8.0 - Optimized & Cleaned!**

## Features

### Core Functionality
- **Automatic Loot Tracking**: Records all items looted automatically
- **Detailed Loot History**: View complete history of looted items with timestamps
- **Item Filtering**: Filter loot by item quality, type, and custom criteria
- **Search Functionality**: Quickly find specific items in your loot history
- **Minimap Button**: Easy access via minimap button (LibDBIcon integration)
- **Player-based Filtering**: Show loot for all players, only yours, or only others
- **Advanced Sorting**: Sort by date, amount, or name
- **Filter List**: Hide specific items from specific players

### TSM & Auctionator Integration (v1.7+)
- **TSM Price Display**: When holding Shift and hovering over items in LootLog, TSM will show prices for the correct quantities from your loot history
- **Auctionator Integration**: Auctionator prices are automatically shown in tooltips when hovering over items in LootLog
- **Seamless Integration**: Both addons work together without conflicts
- **No Additional Setup**: Simply install both addons and they work together automatically

### v1.8.0 Improvements
- **Code Optimization**: Removed debug prints and optimized performance
- **Bug Fixes**: Fixed various issues with item caching and display
- **Async Loading**: Improved item loading with async support
- **Cleaner Code**: Simplified configuration and settings
- **Better Error Handling**: More robust error handling throughout

## Installation

1. Download the latest code as ZIP from the green "Code" button above
2. Extract the `LootLog` folder to your `Interface/AddOns/` directory
3. Restart World of Warcraft or reload your UI with `/reload`

## Usage

### Basic Usage
- **Open LootLog**: Click the minimap button or use `/lootlog` command
- **View Loot History**: Browse through all your looted items
- **Filter Items**: Use the filter options to narrow down your search
- **Item Details**: Click on items to see detailed information

### Advanced Features
- **Shift + Click**: Insert item link into chat
- **Right Click**: Hide/show loot for specific players
- **Search**: Use the search box to find specific items
- **Settings**: Access advanced options through the settings button

### Commands
- `/lootlog` or `/ll` - Toggle the main window
- `/lootlog config` - Open configuration (if AceConfig is available)

## Configuration

### Main Settings
- **Source Filter**: Show all loot, only regular loot, or only Gargul loot
- **Quality Filter**: Set minimum item quality to display
- **Player Filter**: Show loot for all players, only yours, or only others
- **Sorting**: Choose between date, amount, or name sorting
- **Display Options**: Toggle various display settings

### Filter List
- **Hide Items**: Right-click items to hide them from specific players
- **Manage Hidden**: Use the settings window to manage hidden items
- **Add by ID**: Add items to filter list by their item ID

## Dependencies

### Required Libraries (included)
- **Ace3**: Core addon framework
- **LibStub**: Library management
- **LibDataBroker-1.1**: Data broker support
- **LibDBIcon-1.0**: Minimap button support

### Optional Integrations
- **TSM (TradeSkillMaster)**: For price display and quantity calculations
- **Auctionator**: For auction house price display

## Localization

Currently supports:
- **English (enUS)**: Default language
- **Russian (ruRU)**: Full translation

## Technical Details

### Data Storage
- Uses AceDB-3.0 for persistent storage
- Automatic data migration from older versions
- Profile-based settings

### Performance
- Efficient item caching system
- Async item loading
- Optimized list updates
- Minimal memory footprint

## Changelog

### v1.8.0
- **Code Optimization**: Removed debug prints and optimized performance
- **Bug Fixes**: Fixed various issues with item caching and display
- **Async Loading**: Improved item loading with async support
- **Cleaner Code**: Simplified configuration and settings
- **Better Error Handling**: More robust error handling throughout

### v1.7.0
- **Auctionator Integration**: Added automatic price display support
- **Simplified TSM Integration**: Streamlined TSM integration code
- **Better Tooltip Support**: Improved tooltip handling

### v1.6.0
- **Player-based Filtering**: Added ability to filter by player
- **Advanced Sorting**: Added sorting by amount and name
- **Filter List Improvements**: Enhanced filter list functionality

### v1.5.0
- **TSM Integration**: Added TradeSkillMaster price display support
- **Improved UI**: Better user interface and layout
- **Enhanced Filtering**: More filtering options

## Support

For issues, questions, or feature requests, please visit the GitHub repository.

## License

This addon is open source and available under the MIT License.

## Authors

- **Gariloz** - Main developer and maintainer

---

**Note**: This addon is designed specifically for World of Warcraft 3.3.5a (Wrath of the Lich King). It may not work with other versions of the game.
