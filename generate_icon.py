from PIL import Image, ImageDraw

def create_mac_menu_bar_icon(path="icon.png"):
    # Mac menu bar icons should ideally be 16x16 or 22x22 for standard resolution
    # We will draw a simple "H"
    img = Image.new('RGBA', (22, 22), color=(0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Draw simple filled circle with transparent H
    d.ellipse([1, 1, 20, 20], fill=(255, 255, 255, 255))
    
    # We will just draw a black H
    d.line([(7, 6), (7, 16)], fill=(0,0,0,255), width=2)
    d.line([(15, 6), (15, 16)], fill=(0,0,0,255), width=2)
    d.line([(7, 11), (15, 11)], fill=(0,0,0,255), width=2)
    
    img.save(path)

if __name__ == "__main__":
    create_mac_menu_bar_icon("icon.png")
