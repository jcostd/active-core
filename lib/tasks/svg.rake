namespace :svg do
  desc "Normalizza e minifica le icone SVG in app/assets/images/icons/ per l'uso con Tailwind/DaisyUI"
  task normalize: :environment do
    require "nokogiri"

    cartella_icone = Rails.root.join("app/assets/images/icons/*.svg")
    files = Dir.glob(cartella_icone)

    if files.empty?
      puts "📭 Nessun file SVG trovato in app/assets/images/icons/"
      next
    end

    puts "🎨 Inizio normalizzazione di #{files.size} icone..."

    files.each do |file_path|
      begin
        svg_content = File.read(file_path)

        # Saltiamo i file vuoti o corrotti
        next if svg_content.strip.blank?

        doc = Nokogiri::XML(svg_content) do |config|
          config.strict.nonet.noblanks # noblanks aiuta già a rimuovere gli spazi vuoti tra i nodi
        end

        svg_node = doc.at_css("svg")
        unless svg_node
          puts "  ⚠️ #{File.basename(file_path)} ignorato (Nessun tag <svg> trovato)"
          next
        end

        # 1. GESTIONE VIEWBOX E DIMENSIONI (Cruciale per Tailwind)
        unless svg_node["viewBox"]
          w = svg_node["width"].to_i
          h = svg_node["height"].to_i
          if w > 0 && h > 0
            svg_node["viewBox"] = "0 0 #{w} #{h}"
          end
        end

        # Ora possiamo rimuovere le dimensioni fisse in sicurezza
        svg_node.remove_attribute("width")
        svg_node.remove_attribute("height")

        # 2. PULIZIA ATTRIBUTI SPORCHI SUL NODO ROOT
        svg_node.remove_attribute("class")
        svg_node.remove_attribute("style")
        svg_node.remove_attribute("id")

        # 3. NORMALIZZAZIONE COLORI (Iniezione di currentColor)
        # Se l'SVG non ha già un fill o uno stroke esplicito a livello radice, forziamo il fill a currentColor.
        # Le icone Material di Google usano quasi tutte il fill.
        if svg_node["fill"].nil? && svg_node["stroke"].nil?
          svg_node["fill"] = "currentColor"
        else
          svg_node["fill"] = "currentColor" if svg_node["fill"] && svg_node["fill"] != "none"
          svg_node["stroke"] = "currentColor" if svg_node["stroke"] && svg_node["stroke"] != "none"
        end

        # Propaghiamo la pulizia su tutti i percorsi interni
        doc.css("*").each do |el|
          el.remove_attribute("style")

          # Se un elemento interno ha un colore hardcoded (es. #000000), lo forziamo a ereditare
          el["fill"] = "currentColor" if el["fill"] && el["fill"] != "none" && el["fill"] != "currentColor"
          el["stroke"] = "currentColor" if el["stroke"] && el["stroke"] != "none" && el["stroke"] != "currentColor"
        end

        # 4. RIMOZIONE METADATI E COMMENTI INUTILI
        # ATTENZIONE: Lasciamo i <defs> perché servono per maschere e gradienti complessi!
        doc.css("title, desc, metadata").each(&:remove)
        doc.xpath("//comment()").remove

        # 5. SALVATAGGIO MINIFICATO (Niente spazi, niente dichiarazioni XML)
        save_options = Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION

        # Genera l'XML stringa e rimuove brutalmente i ritorni a capo per fare un file di 1 riga
        minified_xml = doc.to_xml(indent: 0, save_with: save_options).gsub(/\n\s*/, "")

        File.write(file_path, minified_xml)

        # Solo per output in console visivamente pulito
        puts "  ✅ #{File.basename(file_path)} normalizzato."

      rescue StandardError => e
        puts "  ❌ ERRORE in #{File.basename(file_path)}: #{e.message}"
      end
    end

    puts "✨ Boom! Tutte le icone sono minificate e pronte per DaisyUI."
  end
end
