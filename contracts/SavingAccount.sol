//SPDX-License-Identifier:MIT;
pragma solidity ^0.6.1;

pragma experimental ABIEncoderV2;
import './GeneralConfiguration.sol';

contract SavingAccount {
    
    // el administrador no puede ser ni gestor ni auditor
    struct Ahorrista
    {
        string cedula;
        string nombreCompleto;
        uint fechaIngreso;
        address cuentaEth;
        address cuentaBeneficenciaEth;
        uint montoAhorro;   //si isActive == false -> seria el dinero que no se suma al ahorro total del contrato
        uint montoAdeudado;
        Banderas banderas;
    }
    
    struct Banderas {
        bool isGestor;
        bool isAuditor;
        bool isActive;
        bool isAproved;
        bool ahorristaHaVotado;
        bool auditorCierraVotacion;
        bool gestorVotaEjecucion;
    }
    
    enum Estado {EnProcesoDeVotacion, Aprobado, PendienteEjecucion ,Ejecutado}
    
    struct SubObjetivo {
        string descripcion;
        uint monto;
        Estado estado;
        address payable ctaDestino;
        uint cantVotos;
    }
    
    uint cantAhorristas;        //incluye todos 
    uint cantAhorristasActivos; //incluye activos (sin importar si estan aprobados o no)
    uint cantAhorristasAproved; //solo los ahorristas isAproved == true
    uint cantGestores;
    uint cantAuditores;
    mapping(address => Ahorrista) public ahorristas;
    mapping(uint => address) public ahorristasIndex;
    SubObjetivo[] public subObjetivos;
    
    GeneralConfiguration public generalConf;
    address payable public administrador;
    bool public isActive;  //para activarlo minimo (Ahorristas >= 6 && Gestores 1 cada 3 Ahorristas && Auditor 1 cada 2 Gestores), pero pueden ser otras cantidades
                           //establecidas en el contrato de configuracion, un ahorrista no puede ser Gestor y Auditor a la vez
    uint cantMaxAhorristas; // >= 6
    uint ahorroActual; //capaz es el balance!!!!
    uint ahorroObjetivo;
    string objetivo;
    uint minAporteDeposito; // >= 0
    uint minAporteActivarCta;
    bool ahorroActualVisiblePorAhorristas;
    bool ahorroActualVisiblePorGestores;

    bool votacionActiva;   //bandera para indicar periodo de votacion activo
    
    uint totalRecibidoDeposito;  //no me queda claro para que sirve
    
    modifier onlyAdmin() {
        require(msg.sender == administrador, 'Not the Admin');
        _;
    }
    
    modifier onlyAhorristas() {
        require(isInAhorristasMapping(msg.sender) == true, 'Not an Ahorrista');
        _;
    }
    
    modifier onlyAuditor() {
        require(ahorristas[msg.sender].banderas.isAuditor == true, 'Not an Auditor');
        _;
    }
    
    modifier onlyAdminOrAuditor() {
        require(msg.sender == administrador || ahorristas[msg.sender].banderas.isAuditor == true, 'Not an Admin or an Auditor');
        _;
    }
    
    modifier onlyGestor() {
        require(ahorristas[msg.sender].banderas.isGestor == true, 'Not an Gestor');
        _;
    }
    
    modifier receiveMinDepositAmount() {
        require(msg.value >= minAporteDeposito, 'Not enough deposit amount');
        _;
    }
    
    modifier savingContractIsActive() {
        require(isActive == true, 'Saving Acccount Contract not active');
        _;
    }
    
    constructor() public {   
        administrador = msg.sender;
        isActive = true; // Solo para test, debe ser false
        votacionActiva = false;
    }

    function setConfigAddress( GeneralConfiguration _address ) public {
        generalConf = _address;
    }
    
    // item 22
    function getAhorroActual() public onlyAdminOrAuditor view returns (uint) {
        return ahorroActual;
    }
    
    //////////////////////////////////////////
    ///////////// Items 6 al 10 //////////////
    /////// Init, Registro y Deposito ////////
    //////////////////////////////////////////

    // Endpoint
    // Item 7 y 9
    function init(uint maxAhorristas, uint ahorroObj, string memory elObjetivo, uint minAporteDep, uint minAporteActivar, bool ahorristaVeAhorroActual, bool gestorVeAhorroActual) public onlyAdmin {
        require(maxAhorristas >= 6, "maxAhorristas must be greater than 5");
        require(minAporteDep >= 0, "minAporteDep must be a positive value"); //ver si sirve
        require(bytes(elObjetivo).length != 0, "elObjetivo must be specified");

        cantMaxAhorristas = maxAhorristas;
        ahorroObjetivo = ahorroObj;
        objetivo = elObjetivo;
        minAporteDeposito = minAporteDep;
        minAporteActivarCta = minAporteActivar;
        ahorroActualVisiblePorAhorristas = ahorristaVeAhorroActual;
        ahorroActualVisiblePorGestores = gestorVeAhorroActual;
    }

    // Endpoint
    // Item 8 y 10
    function sendDepositWithRegistration(string memory cedula, string memory fullName, address addressBeneficiario) public payable savingContractIsActive receiveMinDepositAmount {
        address addressUser = msg.sender;
        if (!isInAhorristasMapping(addressUser)) {
            ahorristas[addressUser].cedula = cedula;
            ahorristas[addressUser].nombreCompleto = fullName;
            ahorristas[addressUser].fechaIngreso = block.timestamp;
            ahorristas[addressUser].cuentaEth = addressUser;
            ahorristas[addressUser].cuentaBeneficenciaEth = addressBeneficiario;
            ahorristas[addressUser].montoAhorro = msg.value;
            ahorristas[addressUser].montoAdeudado = 0;
            ahorristas[addressUser].banderas = Banderas(false,false,false,false,false,false, false);
            ahorristasIndex[cantAhorristas] = addressUser;
            cantAhorristas++;
            if(msg.value >= minAporteActivarCta){
                ahorristas[addressUser].banderas.isActive = true;
                cantAhorristasActivos++;
            }
        }
    }
    
    // Item 6, 8 
    function sendDeposit() public payable savingContractIsActive receiveMinDepositAmount {
        if (isInAhorristasMapping(msg.sender))
        {
            ahorristas[msg.sender].montoAhorro += msg.value;
            if (ahorristas[msg.sender].banderas.isAproved) {
                ahorroActual += msg.value;
            }else if(!ahorristas[msg.sender].banderas.isActive && ahorristas[msg.sender].montoAhorro >= minAporteActivarCta){
                ahorristas[msg.sender].banderas.isActive = true;
                cantAhorristasActivos++;
            }
        }
    }
    
    // Item 10
    function aproveAhorrista(address unAddress) public onlyAuditor returns (bool) {
        bool retorno = false;
        
        if (isInAhorristasMapping(unAddress) && ahorristas[unAddress].banderas.isActive == true) 
        {
            if (isActive == false) 
            {
                ahorristas[unAddress].banderas.isAproved = true;
                cantAhorristasAproved++;
                ahorroActual += ahorristas[unAddress].montoAhorro;
                retorno = true; 
            }
            else if (generalConf.validateRestrictions(cantAhorristasAproved, cantGestores, cantAuditores)) 
            {
                ahorristas[unAddress].banderas.isAproved = true;
                cantAhorristasAproved++;
                ahorroActual += ahorristas[unAddress].montoAhorro;
                retorno = true;
            }  
        }
        return retorno;
    }
    
    // Item 10
    function getAhorristasToAprove() public onlyAuditor view returns(address[] memory) {
        address[] memory losActivosSinAprobar = new address[](cantAhorristasActivos - cantAhorristasAproved);
        uint j = 0;
        if (cantAhorristasActivos - cantAhorristasAproved > 0) 
        {
            for(uint i=0; i<cantAhorristas; i++) {
                if(ahorristas[ahorristasIndex[i]].banderas.isActive && !ahorristas[ahorristasIndex[i]].banderas.isAproved)
                    {
                        losActivosSinAprobar[j] = ahorristas[ahorristasIndex[i]].cuentaEth;    
                        j++;
                    }
            }
        }
        return losActivosSinAprobar;
    }
    
    //////////////////////////////////////////
    ////////// Items 11 al 16 ////////////////
    /////// Votacion de Subobjetivos /////////
    //////////////////////////////////////////
    
    // Endpoint
    function habilitarPeriodoDeVotacion() public onlyAdmin returns(bool) {
        for(uint i=0; i<cantAhorristas; i++) {
            ahorristas[ahorristasIndex[i]].banderas.ahorristaHaVotado = false;
            ahorristas[ahorristasIndex[i]].banderas.auditorCierraVotacion = false;
        }
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.EnProcesoDeVotacion){
                votacionActiva = true;
                return true;
            }
        }
        return false;
    }
    
    // Endpoint - Probar
    function votarCerrarPeriodoDeVotacion() public onlyAuditor returns(string memory){
        if(votacionActiva == false) { return "No existe periodo de votacion abierto"; }
        ahorristas[msg.sender].banderas.auditorCierraVotacion = true;
        
        for(uint i=0; i<cantAhorristas; i++) {
            if (ahorristas[ahorristasIndex[i]].banderas.auditorCierraVotacion == false && ahorristas[ahorristasIndex[i]].banderas.isAuditor == true){
                return "Se ha agregado su voto pero faltan Auditores por votar";
            }
        }
        
        votacionActiva = false;
        
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.EnProcesoDeVotacion && subObjetivos[i].cantVotos > 0){
               subObjetivos[i].estado = Estado.Aprobado;
            }
        }
        
        return "El periodo de votacion ha quedado cerrado";
    }
    
    // Endpoint - Probar
    function ejecutarProxSubObjetivo() public onlyGestor returns (string memory) {
        uint maxVotos = 0;
        uint subObjIndex = 0;
        bool existePendiente = false;
        
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.Aprobado){
               if(subObjetivos[i].cantVotos > maxVotos) {
                   maxVotos = subObjetivos[i].cantVotos;
                   subObjIndex = i;
               }
            }
            if(subObjetivos[i].estado == Estado.PendienteEjecucion){
                existePendiente = true;
            }
        }
        
        //caso feliz tienen plata el subobj number one
        if(maxVotos > 0 && subObjetivos[subObjIndex].monto <= ahorroActual) {
            ejecutarSubObjetivo(subObjIndex);
            return subObjetivos[subObjIndex].descripcion;
        }
        
        if(existePendiente == true) { return "Ya existe un SubObjetivo pendiente de ejecucion"; }
        
        maxVotos = 0;
        subObjIndex = 0;
        
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.Aprobado && subObjetivos[i].monto <= ahorroActual){
              if(subObjetivos[i].cantVotos > maxVotos) {
                  maxVotos = subObjetivos[i].cantVotos;
                  subObjIndex = i;
              }
            }
        }
        
        if(maxVotos > 0) {
            subObjetivos[subObjIndex].estado = Estado.PendienteEjecucion;
            return string(abi.encodePacked(subObjetivos[subObjIndex].descripcion, " (pendiente de ejecucion)"));
        }
    
    }
    
    // Endpoint - Probar
    function votarSubObjetivoPendienteEjecucion(string memory descripcion) public onlyGestor returns(string memory){ 
        //limpiar la bandera esta
        if(ahorristas[msg.sender].banderas.gestorVotaEjecucion == true) { return "Ya habias votado"; }    
            
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.PendienteEjecucion){
                if(keccak256(abi.encodePacked(subObjetivos[i].descripcion)) == keccak256(abi.encodePacked(descripcion))){
                    ahorristas[msg.sender].banderas.gestorVotaEjecucion = true;
                    uint cantGestoresAprobaron = 0;
                    for(uint j=0; j<cantAhorristas; j++) {
                        if (ahorristas[ahorristasIndex[j]].banderas.isGestor == true && ahorristas[ahorristasIndex[j]].banderas.gestorVotaEjecucion == true){
                            cantGestoresAprobaron++;
                        }
                    }
                    if(cantGestoresAprobaron >= 2) {
                        ejecutarSubObjetivo(i);
                        //se resetean las banderas de votos de los gestores
                        for(uint k=0; k<cantAhorristas; k++) {
                            ahorristas[ahorristasIndex[k]].banderas.gestorVotaEjecucion = false;
                        }
                        return string(abi.encodePacked("Se ejecuto el subobjetivo ", subObjetivos[i].descripcion));
                    }
                    return "Se ha agregado su voto pero todavia falta un Gestor por votar";
                }         
            }
        }
        return "No se encontro el subobjetivo";
    }

    // Endpoint
    function getSubObjetivosPendienteEjecucion() public onlyGestor view returns(string[] memory) { 
        uint cantSubObj=0;
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.PendienteEjecucion){
                cantSubObj++;     
            }
        }
        string[] memory losSubObjetivos = new string[](cantSubObj);
        uint j = 0;
        for(uint i=0; i<subObjetivos.length; i++) {
            if(subObjetivos[i].estado == Estado.PendienteEjecucion) {
                losSubObjetivos[j] = subObjetivos[i].descripcion;    
                j++;
            }
        }
        return losSubObjetivos;
    }
    
    // Endpoint - Probar
    function votarSubObjetivoEnProesoDeVotacion(string memory descripcion) public returns(string memory){ //onlyAhorristas
        if(votacionActiva == false) { return "No existe periodo de votacion abierto"; }
        if(tieneCtaActiva() == false){ return "Su cuenta no esta activa, no puede votar"; }
            
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.EnProcesoDeVotacion){
                if(keccak256(abi.encodePacked(subObjetivos[i].descripcion)) == keccak256(abi.encodePacked(descripcion))){
                    subObjetivos[i].cantVotos++;
                    ahorristas[msg.sender].banderas.ahorristaHaVotado = true;
                    return "OK";
                }         
            }
        }
        return "No se encontro el subobjetivo";
    }
    
    // Endpoint
    function addSubObjetivo(string memory desc, uint monto, uint estadoKey, address payable ctaDestino) public onlyAdmin returns(bool) {
        require(estadoKey <= uint(Estado.Ejecutado));
        Estado estado = Estado(estadoKey);
        subObjetivos.push(SubObjetivo(desc, monto, estado, ctaDestino, 0));
        return true;
    }

    // Endpoint
    function getSubObjetivosEnProcesoDeVotacion() public view returns(string[] memory) {  //onlyAhorristas
        uint cantSubObj=0;
        for(uint i=0; i<subObjetivos.length; i++) { 
            if(subObjetivos[i].estado == Estado.EnProcesoDeVotacion){
                cantSubObj++;     
            }
        }
        string[] memory losSubObjetivos = new string[](cantSubObj);
        uint j = 0;
        if (votacionActiva == true && tieneCtaActiva() == true) {
            for(uint i=0; i<subObjetivos.length; i++) {
                if(subObjetivos[i].estado == Estado.EnProcesoDeVotacion) {
                    losSubObjetivos[j] = subObjetivos[i].descripcion;
                    j++;
                }
            }
        }
        return losSubObjetivos;
    }

    // Endpoint
    function tieneCtaActiva() public view returns (bool) {  //onlyAhorristas
        return ahorristas[msg.sender].banderas.isActive == true;
    }

    function ejecutarSubObjetivo(uint index) private {
        subObjetivos[index].estado = Estado.Ejecutado;
        ahorroActual =- subObjetivos[index].monto;
        subObjetivos[index].ctaDestino.transfer(subObjetivos[index].monto);
    }

    //////////////////////////////////////////
    ///////// Funciones Auxiliares ///////////
    //////////////////////////////////////////

    function isInAhorristasMapping(address unAddress) private view returns(bool)
    {
        return ahorristas[unAddress].cuentaEth != address(0);
    }
    
    //////////////////////////////////////////
    ////////// METODOS DE PRUEBA /////////////
    //////////////////////////////////////////
    
    // Endpoint
    function setRol(bool auditor, bool gestor) public {
        ahorristas[msg.sender].banderas.isAuditor = auditor;
        ahorristas[msg.sender].banderas.isGestor = gestor;
    }
    
    // Endpoint
    function getOneField() public view returns (address){
        return ahorristas[msg.sender].cuentaEth;
    }

    // Endpoint
    function setActive(bool activeStatus) public returns(bool) {
        address ads = msg.sender;
        ahorristas[ads].banderas.isActive = activeStatus;
        return true;
    }

    // Endpoint
    function getVotacionActiva() public view returns(bool) {
        return votacionActiva;
    }

    // Endpoint
    function setVotacionActiva(bool state) public {
        votacionActiva = state;
    }

    // Endpoint
    function getAhorrista(address ads) public view returns(Ahorrista memory){
        return ahorristas[ads];
    }

    // Endpoint
    function savingAccountStatePart1() public view returns(uint, uint, string memory, uint, uint, bool, bool, uint) {
        uint v1 = cantMaxAhorristas;
        uint v2 = ahorroObjetivo;
        string memory v3 = objetivo;
        uint v4 = minAporteDeposito;
        uint v5 = minAporteActivarCta;
        bool v6 = ahorroActualVisiblePorAhorristas;
        bool v7 = ahorroActualVisiblePorGestores;
        uint v8 = cantAhorristas;
        return (v1, v2, v3, v4, v5, v6, v7, v8);
    }

    // Endpoint
    function savingAccountStatePart2() public view returns(uint, uint, uint, uint, address, bool, uint, uint) {
        uint v9 = cantAhorristasActivos;
        uint v10 = cantAhorristasAproved;
        uint v11 = cantGestores;
        uint v12 = cantAuditores;
        address v13 = administrador;
        bool v14 = isActive;
        uint v15 = ahorroActual;
        uint v16 = totalRecibidoDeposito;
        return (v9, v10, v11, v12, v13, v14, v15, v16);
    }

}