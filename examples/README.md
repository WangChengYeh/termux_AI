# Termux AI Examples

This directory contains example configurations and usage patterns for Termux AI.

## android_sourceme Configuration

The `android_sourceme_example.sh` file shows how to customize your Termux AI environment by placing a configuration file at `/data/local/tmp/android_sourceme`.

### Setup Instructions

1. **Copy the example file**:
   ```bash
   adb push examples/android_sourceme_example.sh /data/local/tmp/android_sourceme
   ```

2. **Make it executable**:
   ```bash
   adb shell "chmod +x /data/local/tmp/android_sourceme"
   ```

3. **Launch Termux AI** - the configuration will be automatically loaded

### What You Can Configure

- **Environment Variables**: Set custom variables for your development workflow
- **Aliases**: Create shortcuts for commonly used commands
- **Functions**: Define custom shell functions
- **PATH Modifications**: Add additional directories to your PATH
- **Development Settings**: Configure editors, browsers, and other tools

### Example Customizations

```bash
# Custom environment variables
export GITHUB_USER="yourusername"
export EDITOR="vim"

# Useful aliases
alias ll='ls -la'
alias gst='git status'
alias gco='git checkout'

# Development shortcuts
alias serve='python -m http.server 8000'
alias jsonpp='python -m json.tool'

# Custom functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

gitclone() {
    gh repo clone "$1" && cd "$(basename "$1")"
}
```

### Advanced Usage

You can make the configuration conditional based on various factors:

```bash
# Different settings for different Android versions
if [ "$(getprop ro.build.version.sdk)" -ge 30 ]; then
    export ANDROID_11_PLUS=true
fi

# Custom setup based on device properties
DEVICE_MODEL=$(getprop ro.product.model)
if [ "$DEVICE_MODEL" = "Pixel 6" ]; then
    export DEVICE_SPECIFIC_SETTING=true
fi
```

### Security Considerations

- The `/data/local/tmp/android_sourceme` file is executed with the same privileges as the Termux AI app
- Only place trusted code in this file
- Be careful with environment variables that might affect security
- Consider using conditional logic to avoid conflicts with existing settings

### Testing Your Configuration

After setting up your `android_sourceme` file:

1. **Launch Termux AI**
2. **Check if your settings loaded**: Look for any echo statements you added
3. **Test your aliases and functions**: Ensure they work as expected
4. **Verify environment variables**: Use `echo $VARIABLE_NAME` to check values

### Troubleshooting

If your configuration isn't loading:

1. **Check file permissions**: Ensure the file is readable
2. **Verify file location**: Must be exactly `/data/local/tmp/android_sourceme`
3. **Check syntax**: Use `sh -n /data/local/tmp/android_sourceme` to validate
4. **Review logs**: Look for error messages during app startup

The configuration is sourced every time you start a new shell session in Termux AI, making it easy to test and iterate on your setup.