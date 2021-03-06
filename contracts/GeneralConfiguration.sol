//SPDX-License-Identifier:MIT;
pragma solidity ^0.6.1;

contract GeneralConfiguration {

    address payable public owner;
    uint minCantAhorristas;
    uint minCantGestores;
    uint minCantAuditores;
    uint pctComisionLiquidacion;
    uint dolaresComisionApertura;
    uint cotizacionDolar;

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not the owner');
        _;
    }
    
    modifier validateRelationBetweenRoles(uint minAhorristas, uint minGestores, uint minAuditores) {
        require(minAhorristas >= 6, "minAhorristas must be greater than 5");
        require(minAhorristas >= minGestores && minAhorristas >= minAuditores, "can not be more Gestores or Auditores than Ahorristas");
        require(minGestores * 3 >= minAhorristas, "one Gestor is needed every 3 Ahorristas");
        require(minAuditores * 2 >= minGestores, "one Auditor is needed every 2 Gestores");
        _;
    }
    
    constructor() public {
        owner = msg.sender;
        minCantAhorristas = 6;
        minCantGestores = 2;
        minCantAuditores = 1;
        pctComisionLiquidacion = 10;
        dolaresComisionApertura = 10;
        cotizacionDolar = 5;
    }

    function setRestrictions(uint minAhorristas, uint minGestores, uint minAuditores) public onlyOwner validateRelationBetweenRoles(minAhorristas, minGestores, minAuditores){
        minCantAhorristas = minAhorristas;
        minCantGestores = minGestores;
        minCantAuditores = minAuditores;
    }
    
    //valida la relacion entre las cant de Ahorristas, Gestores y Auditores
    function validateRestrictions(uint cantAho, uint cantGest, uint cantAud) public validateRelationBetweenRoles(cantAho, cantGest, cantAud) view returns (bool) {
        return cantAho >= minCantAhorristas && cantGest >= minCantGestores && cantAud >= minCantAuditores;
    }

    function isValid(uint cantAho, uint cantGest, uint cantAud) public pure returns(bool) {
        bool valid = true;
        valid = valid && cantAho >= 6;
        valid = valid && cantAho >= cantGest && cantAho >= cantAud;
        valid = valid && cantGest * 3 >= cantAud;
        valid = valid && cantAud * 2 >= cantGest;
        return valid;
    }

    function setPctComisionLiquidacion(uint pComisionLiquidacion) public onlyOwner {
        pctComisionLiquidacion = pComisionLiquidacion;
    }

    function setDolaresComisionApertura(uint dlsComisionApertura) public onlyOwner {
        dolaresComisionApertura = dlsComisionApertura;
    }

    function setCotizacionDolar(uint cotDolar) public onlyOwner {
        cotizacionDolar = cotDolar;
    }

    function getPctComisionLiquidacion(uint montoAhorro) public view returns(uint) {
        return uint((montoAhorro*pctComisionLiquidacion)/100);
    }
    
    function getComisionApertura() public view returns(uint) {
        return dolaresComisionApertura*cotizacionDolar;
    }

    function getAddressToPay() public view returns(address payable) {
        return owner;
    }

}
