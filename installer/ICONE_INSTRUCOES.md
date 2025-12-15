# Instruções para Configurar o Ícone

## Passo 1: Converter a Imagem PNG para ICO

Você tem algumas opções para converter sua imagem PNG (logo GZ) para formato ICO:

### Opção A: Usando o Script Automatizado (Recomendado)

1. Coloque sua imagem PNG na pasta `installer/`
2. Execute:
   ```batch
   cd installer
   convert_png_to_ico.bat logo.png
   ```
   (Substitua `logo.png` pelo nome do seu arquivo)

### Opção B: Usando ImageMagick (Se instalado)

```batch
magick logo.png -define icon:auto-resize=16,32,48,64,128,256 app_icon.ico
```

### Opção C: Conversor Online

1. Acesse: https://convertio.co/png-ico/ ou https://www.icoconverter.com/
2. Faça upload da sua imagem PNG
3. Configure para gerar múltiplos tamanhos: 16x16, 32x32, 48x48, 64x64, 128x128, 256x256
4. Baixe o arquivo ICO gerado

## Passo 2: Colocar o Ícone no Projeto

Depois de ter o arquivo `app_icon.ico`, copie-o para:

```
windows\runner\resources\app_icon.ico
```

Substitua o arquivo existente se necessário.

## Passo 3: Verificar

O ícone será usado automaticamente:
- No executável `.exe` do aplicativo
- No instalador gerado pelo Inno Setup
- Nos atalhos criados durante a instalação

## Notas Importantes

- O arquivo ICO deve conter múltiplos tamanhos para melhor qualidade em diferentes contextos
- Tamanhos recomendados: 16x16, 32x32, 48x48, 64x64, 128x128, 256x256 pixels
- O ícone será exibido na barra de tarefas, área de trabalho e menu Iniciar do Windows



