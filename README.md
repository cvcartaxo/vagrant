# vagrant

Antes de começar, instale:

- [Vagrant](https://developer.hashicorp.com/vagrant/downloads)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) 

## 🚀 Como usar

1. **Clone este repositório**
   ```bash
   git clone git@github.com:cvcartaxo/vagrant.git
   cd vagrant

- Para criar o ambiente.

   vagrant up

## ⚙️ Configurações principais (Vagrantfile)

- **Box base:** `bento/ubuntu-22.04`  
- **Memória:** `2048 MB`
- **CPUs:** `2`  
- **Provisão Master:** `scripts/master.sh`
- **Provisão Worker 1:** `scripts/provision-worker-1.sh`
- **Provisão Worker 2:** `scripts/provision-worker-1.sh`

> 💡 Você pode ajustar essas configurações diretamente no arquivo **Vagrantfile**.

