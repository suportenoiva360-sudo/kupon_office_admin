# Ícones da Aplicação KupON

Para gerar os ícones da aplicação em todas as plataformas, você precisa criar as seguintes imagens:

## Imagens Necessárias

### 1. `icon.png` (Principal)
- **Tamanho recomendado**: 1024x1024 pixels
- **Formato**: PNG com transparência
- **Descrição**: Ícone principal do aplicativo usado em todas as plataformas

### 2. `icon_foreground.png` (Android Adaptativo)
- **Tamanho recomendado**: 1024x1024 pixels (área segura: 432x432 no centro)
- **Formato**: PNG com transparência
- **Descrição**: Camada de primeiro plano para ícones adaptativos Android
- **Nota**: Deixe uma margem de ~30% ao redor do elemento principal

### 3. `icon_round.png` (Android Redondo - Opcional)
- **Tamanho recomendado**: 1024x1024 pixels
- **Formato**: PNG
- **Descrição**: Versão circular do ícone para dispositivos que suportam ícones redondos

## Design Sugerido

Com base no tema do app:
- **Cores principais**: 
  - Laranja/Coral: `#FF6B00` (Primary Container)
  - Fundo: `#131313` (Surface)
- **Elemento**: Ícone de cupom/oferta (local_offer_rounded)
- **Estilo**: Moderno, minimalista, com bordas arredondadas

## Como Gerar os Ícones

Após criar as imagens acima nesta pasta, execute:

```bash
flutter pub run icons_launcher:create
```

Isso irá gerar automaticamente todos os ícones necessários para:
- ✅ Android (mipmap, adaptive icons)
- ✅ iOS (AppIcon)
- ✅ Web (favicon, manifest icons)
- ✅ Windows
- ✅ macOS
- ✅ Linux

## Ferramentas Recomendadas

- **Figma**: Para criar designs vetoriais
- **GIMP/Photoshop**: Para edição de imagens
- **Online**: 
  - [Canva](https://www.canva.com/)
  - [Figma](https://www.figma.com/)
  - [Adobe Express](https://www.adobe.com/express/)

## Exemplo de Estrutura

```
assets/images/
├── icon.png              # 1024x1024 - Ícone principal
├── icon_foreground.png   # 1024x1024 - Android foreground
├── icon_round.png        # 1024x1024 - Android round (opcional)
└── README.md             # Este arquivo
```

## Configuração Atual

O arquivo `icons_launcher.yaml` na raiz do projeto já está configurado com:
- Background color Android: `#FF6B00`
- Background color Web: `#131313`
- Theme color Web: `#FF6B00`

---

**Nota**: Se você não tiver as imagens prontas ainda, pode usar um ícone temporário ou o ícone padrão do Flutter até criar os personalizados.
